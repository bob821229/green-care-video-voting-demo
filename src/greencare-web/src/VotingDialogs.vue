<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { api } from './api'
import type { Bootstrap, Video, Vote, WatchProgress } from './types'

declare global {
  interface Window { YT?:any; onYouTubeIframeAPIReady?:()=>void; grecaptcha?:any; onRecaptchaReady?:()=>void }
}

const props=defineProps<{data:Bootstrap}>()
const emit=defineEmits<{updated:[Bootstrap];resultsChanged:[]}>()
const watchDialog=ref<HTMLDialogElement>(),confirmDialog=ref<HTMLDialogElement>(),playerHost=ref<HTMLElement>(),captchaBox=ref<HTMLElement>(),developmentCaptchaInput=ref<HTMLInputElement>()
const current=ref<Video|null>(null),player=ref<any>(null),playerState=ref<number|null>(null),sessionId=ref(''),timer=ref<number>(),captchaToken=ref(''),captchaId=ref<number|null>(null),busy=ref(false),message=ref(''),messageError=ref(false)
const confirmTitle=ref(''),confirmMessage=ref(''),confirmText=ref('確認'),confirmTone=ref('vote')
let confirmationResolve:((answer:boolean)=>void)|null=null
let captchaLoadPromise:Promise<void>|null=null

const groupName=computed(()=>current.value?.category==='team'?'團體組':'個人組')
const currentVote=computed(()=>current.value?props.data.votes.find(v=>v.videoId===current.value!.id):undefined)
const ratio=computed(()=>current.value?props.data.progress.find(p=>p.videoId===current.value!.id)?.ratio??0:0)
const qualified=computed(()=>ratio.value>=.8||Boolean(current.value&&props.data.progress.find(p=>p.videoId===current.value!.id)?.qualified))
const groupVotes=computed(()=>current.value?props.data.votes.filter(v=>v.category===current.value!.category):[])
const groupFull=computed(()=>!currentVote.value&&groupVotes.value.length>=2)
const showCaptcha=computed(()=>!currentVote.value&&!groupFull.value&&qualified.value&&props.data.activity.state==='active')
const captchaVisible=computed(()=>!props.data.recaptchaSiteKey||captchaId.value!==null)
const videosInGroup=computed(()=>props.data.videos.filter(v=>v.category===current.value?.category))
const currentIndex=computed(()=>videosInGroup.value.findIndex(v=>v.id===current.value?.id))
const canVote=computed(()=>!busy.value&&!currentVote.value&&!groupFull.value&&Boolean(current.value?.youtubeId)&&qualified.value&&props.data.activity.state==='active')
const voteButtonText=computed(()=>currentVote.value?(currentVote.value.status==='flagged'?'此票待確認':'已投給這支作品'):!current.value?.youtubeId?'影片尚未開放':!qualified.value?'尚未達投票門檻':props.data.activity.state!=='active'?'目前不在投票期間':groupFull.value?'請先取消一票':busy.value?'處理中':`投給作品 ${current.value.number}`)
const progressPercent=computed(()=>Math.min(100,Math.floor(ratio.value*100)))

function voteWork(vote:Vote){return props.data.videos.find(v=>v.id===vote.videoId)}
function setMessage(text:string,error=false){message.value=text;messageError.value=error}
function deviceSignal(){return [navigator.platform,navigator.language,screen.width,screen.height,Intl.DateTimeFormat().resolvedOptions().timeZone].join('|')}
function syncUrl(id?:number){const url=new URL(location.href);id?url.searchParams.set('work',String(id)):url.searchParams.delete('work');url.hash=id?'works':'';history.replaceState(null,'',url)}

async function ytReady(){
  if(window.YT?.Player)return
  await new Promise<void>((resolve,reject)=>{const old=window.onYouTubeIframeAPIReady;window.onYouTubeIframeAPIReady=()=>{old?.();resolve()};if(!document.querySelector('script[data-youtube-api]')){const script=document.createElement('script');script.src='https://www.youtube.com/iframe_api';script.dataset.youtubeApi='true';script.onerror=()=>reject(new Error('YouTube 播放器載入失敗。'));document.head.appendChild(script)}})
}
async function createPlayer(video:Video){
  if(!video.youtubeId||!playerHost.value)return
  try{await ytReady();if(current.value?.id!==video.id)return;player.value=new window.YT.Player(playerHost.value,{videoId:video.youtubeId,playerVars:{rel:0,playsinline:1},events:{onReady:onPlayerReady,onStateChange:onPlayerState}})}catch(error){setMessage(error instanceof Error?error.message:'YouTube 播放器載入失敗。',true)}
}
async function onPlayerReady(){try{const result=await api<{sessionId:string}>('/api/watch/start',{method:'POST',body:JSON.stringify({videoId:current.value!.id,duration:player.value.getDuration()})});sessionId.value=result.sessionId}catch(error){setMessage(error instanceof Error?error.message:'無法建立觀看紀錄。',true)}}
function onPlayerState(event:{data:number}){const previous=playerState.value;playerState.value=event.data;clearTimer();if(event.data===window.YT.PlayerState.PLAYING)timer.value=window.setInterval(()=>sendProgress('tick',true),5000);else if(previous===window.YT.PlayerState.PLAYING)void sendProgress('transition',true)}
async function sendProgress(event='tick',playing?:boolean){if(!sessionId.value||!player.value?.getCurrentTime||!current.value)return;try{const update=await api<{ratio:number;qualified:boolean}>('/api/watch/progress',{method:'POST',body:JSON.stringify({sessionId:sessionId.value,position:player.value.getCurrentTime(),playbackRate:player.value.getPlaybackRate(),playing:playing??playerState.value===window.YT?.PlayerState?.PLAYING,visible:document.visibilityState==='visible',event})});const existing=props.data.progress.find(p=>p.videoId===current.value!.id);if(existing){existing.ratio=Math.max(existing.ratio,update.ratio);existing.qualified=Boolean(existing.qualified)||update.qualified}else props.data.progress.push({videoId:current.value.id,ratio:update.ratio,qualified:update.qualified});if(update.qualified&&!captchaToken.value){await nextTick();await setupCaptcha()}}catch(error){setMessage(error instanceof Error?error.message:'觀看進度更新失敗。',true)}}
function clearTimer(){if(timer.value)window.clearInterval(timer.value);timer.value=undefined}
function resetCaptcha(){captchaToken.value='';if(captchaId.value!==null)window.grecaptcha?.enterprise?.reset(captchaId.value);if(developmentCaptchaInput.value)developmentCaptchaInput.value.checked=false}

async function open(videoId:number){const video=props.data.videos.find(v=>v.id===videoId);if(!video)return;clearTimer();player.value?.destroy?.();resetCaptcha();current.value=video;sessionId.value='';playerState.value=null;message.value='';syncUrl(video.id);watchDialog.value?.showModal();await nextTick();if(showCaptcha.value)await setupCaptcha();void createPlayer(video)}
async function navigate(offset:number){const target=videosInGroup.value[currentIndex.value+offset];if(!target)return;if(playerState.value===window.YT?.PlayerState?.PLAYING)await sendProgress('transition',true);await open(target.id)}
function close(){clearTimer();if(playerState.value===window.YT?.PlayerState?.PLAYING)void sendProgress('transition',true);player.value?.stopVideo?.();player.value?.destroy?.();player.value=null;watchDialog.value?.close();syncUrl()}

async function setupCaptcha(){
  captchaToken.value=''
  if(!props.data.recaptchaSiteKey)return
  if(captchaId.value!==null){window.grecaptcha?.enterprise?.reset(captchaId.value);return}
  if(!window.grecaptcha?.enterprise&&!captchaLoadPromise){
    captchaLoadPromise=new Promise<void>((resolve,reject)=>{
      const timeout=window.setTimeout(()=>reject(new Error('驗證元件載入逾時，請重新整理後再試。')),15000)
      window.onRecaptchaReady=()=>{window.clearTimeout(timeout);resolve()}
      const script=document.createElement('script')
      script.src='https://www.google.com/recaptcha/enterprise.js?onload=onRecaptchaReady&render=explicit'
      script.dataset.recaptchaApi='true'
      script.async=true
      script.defer=true
      script.onerror=()=>{window.clearTimeout(timeout);script.remove();reject(new Error('驗證元件載入失敗。'))}
      document.head.appendChild(script)
    })
  }
  try{await captchaLoadPromise}catch(error){captchaLoadPromise=null;setMessage(error instanceof Error?error.message:'驗證元件載入失敗。',true);return}
  if(window.grecaptcha?.enterprise&&captchaBox.value&&captchaId.value===null)captchaId.value=window.grecaptcha.enterprise.render(captchaBox.value,{sitekey:props.data.recaptchaSiteKey,action:'vote',callback:(token:string)=>captchaToken.value=token,'expired-callback':()=>captchaToken.value=''})
}
watch(showCaptcha,async visible=>{if(visible){await nextTick();await setupCaptcha()}})
function developmentCaptcha(checked:boolean){captchaToken.value=checked?'development-pass':''}
function askConfirmation(title:string,body:string,accept:string,tone='vote'){confirmTitle.value=title;confirmMessage.value=body;confirmText.value=accept;confirmTone.value=tone;confirmDialog.value?.showModal();return new Promise<boolean>(resolve=>confirmationResolve=resolve)}
function finishConfirmation(answer:boolean){confirmDialog.value?.close();const resolve=confirmationResolve;confirmationResolve=null;resolve?.(answer)}

async function reload(){const data=await api<Bootstrap>('/api/bootstrap');emit('updated',data);emit('resultsChanged')}
async function submitVote(){
  if(groupFull.value){setMessage('本組已投滿 2 票，請先前往已投票的作品取消其中一票。',true);return}
  if(!captchaToken.value){setMessage('請先完成「我不是機器人」驗證。',true);return}
  const text=`投給「作品 ${current.value!.number}－${current.value!.title}」。`
  if(!await askConfirmation('確認投票',text,'確認投票'))return
  busy.value=true
  try{await api('/api/votes',{method:'POST',body:JSON.stringify({videoId:current.value!.id,recaptchaToken:captchaToken.value,deviceSignal:deviceSignal()})});setMessage('投票成功，謝謝你的參與。');await reload()}catch(error){setMessage(error instanceof Error?error.message:'投票失敗。',true)}finally{busy.value=false;resetCaptcha()}
}
async function cancelVote(){if(!currentVote.value)return;if(!await askConfirmation('取消投票',`取消投給「作品 ${current.value!.number}－${current.value!.title}」的票，該組將立即釋放一票額度。`,'確認取消','cancel'))return;busy.value=true;try{await api(`/api/votes/${currentVote.value.id}`,{method:'DELETE'});setMessage('已取消投票。');await reload()}catch(error){setMessage(error instanceof Error?error.message:'取消投票失敗。',true)}finally{busy.value=false}}
async function visibilityChanged(){
  clearTimer()
  await sendProgress('visibility',false)
  if(!document.hidden&&playerState.value===window.YT?.PlayerState?.PLAYING)timer.value=window.setInterval(()=>sendProgress('tick',true),5000)
}
document.addEventListener('visibilitychange',visibilityChanged)
onBeforeUnmount(()=>{document.removeEventListener('visibilitychange',visibilityChanged);clearTimer();player.value?.destroy?.()})
defineExpose({open})
</script>

<template>
  <dialog ref="confirmDialog" class="confirm-dialog" :data-tone="confirmTone" aria-labelledby="confirmTitle" aria-describedby="confirmMessage" @cancel.prevent="finishConfirmation(false)" @click.self="finishConfirmation(false)">
    <div class="confirm-mark" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M12 7v6M12 17h.01"/></svg></div><div class="confirm-copy"><p class="confirm-eyebrow">投票確認</p><h2 id="confirmTitle">{{confirmTitle}}</h2><p id="confirmMessage">{{confirmMessage}}</p></div><div class="confirm-actions"><button class="confirm-secondary" type="button" @click="finishConfirmation(false)">返回</button><button class="confirm-primary" type="button" @click="finishConfirmation(true)">{{confirmText}}</button></div>
  </dialog>
  <dialog ref="watchDialog" class="watch-dialog" :data-category="current?.category" @cancel.prevent="close">
    <button class="close" type="button" aria-label="關閉播放器" @click="close"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18"/></svg></button>
    <div class="player-wrap"><div ref="playerHost"></div><div v-if="current&&!current.youtubeId" class="unavailable">影片尚未設定，請稍後再來。</div></div>
    <div class="watch-info">
      <div class="watch-heading"><p class="eyebrow">{{groupName}} {{current?.number}}</p><h2>{{current?.title}}</h2><p>新北市淡水區忠寮社區</p></div>
      <div class="progress-block"><div class="progress-label"><span>有效觀看進度</span><strong>{{progressPercent}}%</strong></div><div class="progress"><span :style="{width:`${progressPercent}%`}"></span></div><p>觀看達 80% 後即可投票。快轉及背景播放不列入進度。</p></div>
      <div v-if="groupFull" class="replace-panel"><strong>本組已投滿 2 票。請先前往已投票的作品，確認後取消其中一票：</strong><div><button v-for="vote in groupVotes" :key="vote.id" type="button" @click="open(vote.videoId)"><span>作品 {{voteWork(vote)?.number}}・{{voteWork(vote)?.title}}</span><em>前往查看</em></button></div></div>
      <div v-show="showCaptcha" ref="captchaBox" class="recaptcha-box" :class="{'captcha-visible':captchaVisible}"><label v-if="!data.recaptchaSiteKey" class="demo-captcha"><input ref="developmentCaptchaInput" type="checkbox" @change="developmentCaptcha(($event.target as HTMLInputElement).checked)"> <span><strong>{{data.demo?'展示版驗證':'本機開發驗證'}}</strong><small>正式環境將使用 reCAPTCHA</small></span></label></div>
      <button class="vote-button" type="button" :disabled="!canVote" @click="submitVote">{{voteButtonText}}</button><button v-if="currentVote&&data.activity.state==='active'" class="cancel-vote-button" type="button" :disabled="busy" @click="cancelVote">取消這一票</button>
      <p class="message" :class="messageError?'error':'success'" role="status">{{message}}</p>
      <nav class="video-pagination" aria-label="切換參賽影片"><button type="button" :disabled="currentIndex<=0" @click="navigate(-1)"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m15 5-7 7 7 7"/></svg><span>上一部</span></button><button type="button" :disabled="currentIndex<0||currentIndex>=videosInGroup.length-1" @click="navigate(1)"><span>下一部</span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m9 5 7 7-7 7"/></svg></button></nav>
    </div>
  </dialog>
</template>
