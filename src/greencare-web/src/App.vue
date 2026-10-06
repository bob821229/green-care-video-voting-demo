<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { api } from './api'
import { assetPath, resultsPath } from './paths'
import VotingDialogs from './VotingDialogs.vue'
import type { Bootstrap, Category, Results } from './types'
const category=ref<Category>('individual'), menuOpen=ref(false), bootstrap=ref<Bootstrap|null>(null), results=ref<Results|null>(null), loadError=ref('')
const visibleVideos=computed(()=>bootstrap.value?.videos.filter(v=>v.category===category.value)??[])
const remaining=computed(()=>bootstrap.value?.remaining[category.value]??2)
const voteFor=(id:number)=>bootstrap.value?.votes.find(v=>v.videoId===id)
const resultFor=(id:number)=>results.value&&[...results.value.groups.individual,...results.value.groups.team].find(v=>v.id===id)
function cardStatus(id:number){const vote=voteFor(id);if(vote)return vote.status==='flagged'?'待確認':'已投票';const ratio=bootstrap.value?.progress.find(p=>p.videoId===id)?.ratio??0;return ratio>=.8?'可投票':ratio>0?`已觀看 ${Math.floor(ratio*100)}%`:'開始觀看'}
const dialogs=ref<InstanceType<typeof VotingDialogs>>()
const resultsUrl=resultsPath()
let resultsTimer:number|undefined
async function refreshResults(){try{results.value=await api<Results>('/api/results')}catch{}}
function updateBootstrap(data:Bootstrap){bootstrap.value=data}
onMounted(async()=>{try{bootstrap.value=await api<Bootstrap>('/api/bootstrap');await refreshResults();const requested=Number(new URLSearchParams(location.search).get('work'));if(requested&&bootstrap.value.videos.some(v=>v.id===requested))dialogs.value?.open(requested);resultsTimer=window.setInterval(refreshResults,30000)}catch{loadError.value='作品資料暫時無法載入，請稍後再試。'}})
onBeforeUnmount(()=>{if(resultsTimer)window.clearInterval(resultsTimer)})
</script>

<template>
  <header id="top" class="hero">
    <nav class="nav" aria-label="主要導覽">
      <a class="brand" href="#top" aria-label="綠色照顧－回到首頁" @click="menuOpen=false"><img class="brand-logo" :src="assetPath('images/logo.png')" alt="綠色照顧"></a>
      <button class="nav-toggle" type="button" :aria-expanded="menuOpen" aria-controls="mainMenu" :aria-label="menuOpen?'關閉選單':'開啟選單'" @click="menuOpen=!menuOpen"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16"/></svg></button>
      <div id="mainMenu" class="nav-menu" :class="{open:menuOpen}"><a href="#works" @click="menuOpen=false">參賽作品</a><a href="#rules" @click="menuOpen=false">投票辦法</a><a :href="resultsUrl">票選結果</a></div>
    </nav>
    <div class="hero-art-stage">
      <picture class="hero-official-art" aria-hidden="true">
        <source media="(max-width: 800px)" :srcset="assetPath('assets/campaign/banner/hero-mobile-title.svg')">
        <img :src="assetPath('assets/campaign/banner/hero-desktop-title.svg')" alt="">
      </picture>
      <h1 class="visually-hidden">綠照好時光－短影音競賽網路人氣票選，票選期間 10 月 12 日 10:00 至 10 月 23 日 17:00</h1>
      <div class="hero-inner hero-inner-hidden" aria-hidden="true">
        <div class="hero-meta hero-cta"><p><strong>30 支初賽入圍影片</strong><br>為你喜愛的作品投下一票！</p><a class="primary-link" href="#works">開始觀賞</a></div>
        <a class="hero-scroll" href="#rules" aria-label="查看投票辦法"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 9 7 7 7-7"/></svg></a>
      </div>
    </div>
  </header>
  <main>
    <section id="rules" class="rules-brief" aria-labelledby="rulesTitle">
      <div class="rules-brief-heading"><h2 id="rulesTitle">投票辦法</h2></div>
      <ol><li><strong>每組2票</strong><span>個人組、團體組<br>各投2部</span></li><li><strong>觀看80%</strong><span>達到有效觀看門檻<br>才開始投票</span></li><li><strong>不重複</strong><span>同一作品<br>不能投兩票</span></li><li><strong>可改投</strong><span>前往原作品取消<br>再投其他作品</span></li></ol>
      <p>快轉、背景播放、暫停及異常倍速不列入有效觀看進度。</p>
    </section>
    <section id="works" class="works" aria-labelledby="worksTitle">
      <div class="section-heading"><div><h2 id="worksTitle">初賽入圍影片</h2><p class="works-subtitle">線上展映</p></div></div>
      <div class="category-tabs" role="tablist" aria-label="參賽組別">
        <button id="individualTab" class="category-tab" :class="{active:category==='individual'}" type="button" role="tab" :aria-selected="category==='individual'" aria-controls="videoGrid" @click="category='individual'"><span>個人組</span><small>15 支初賽入圍</small></button>
        <button id="teamTab" class="category-tab" :class="{active:category==='team'}" type="button" role="tab" :aria-selected="category==='team'" aria-controls="videoGrid" @click="category='team'"><span>團體組</span><small>15 支初賽入圍</small></button>
      </div>
      <div class="group-heading"><div><p>{{category==='individual'?'個人組':'團體組'}}</p><span>{{category==='individual'?'個人參賽作品':'團體參賽作品'}}</span></div><strong aria-live="polite">已投 {{2-remaining}} 票 / 尚餘 {{remaining}} 票</strong></div>
      <p v-if="loadError" class="empty" role="alert">{{loadError}}</p>
      <div v-else id="videoGrid" class="video-grid" :data-category="category" role="tabpanel" :aria-labelledby="`${category}Tab`" aria-live="polite">
        <button v-for="video in visibleVideos" :key="video.id" class="video-card" :class="{voted:voteFor(video.id)}" type="button" :aria-label="`作品 ${video.number} ${video.title}，${cardStatus(video.id)}`" @click="dialogs?.open(video.id)">
          <span class="card-poster"><img :src="assetPath(video.poster)" alt="" loading="lazy"><span class="video-number">{{video.number}}</span><span class="card-state">{{cardStatus(video.id)}}</span></span>
          <span class="card-content"><h3>{{video.title}}</h3><span class="team">新北市淡水區忠寮社區</span><strong class="card-votes">{{resultFor(video.id)?.votes.toLocaleString('zh-TW')??'—'}}票</strong></span>
        </button>
      </div>
    </section>
    <section id="live-results" class="live-summary" aria-labelledby="liveResultsTitle">
      <div class="section-heading"><div class="live-title-row"><h2 id="liveResultsTitle">即時票選排行</h2></div><a class="primary-link" :href="resultsUrl">查看完整排名</a></div>
      <div class="summary-groups"><div><h3>個人組</h3><ol class="summary-list"><li v-for="item in results?.groups.individual.slice(0,3)??[]" :key="item.id" :data-work-id="item.id" role="button" tabindex="0" :aria-label="`開啟作品 ${item.number} ${item.title}`" @click="dialogs?.open(item.id)" @keydown.enter="dialogs?.open(item.id)" @keydown.space.prevent="dialogs?.open(item.id)"><strong>{{item.rank}}</strong><span>作品 {{item.number}}・{{item.title}}</span><em><b>{{item.votes.toLocaleString('zh-TW')}}票</b></em></li></ol></div><div><h3>團體組</h3><ol class="summary-list"><li v-for="item in results?.groups.team.slice(0,3)??[]" :key="item.id" :data-work-id="item.id" role="button" tabindex="0" :aria-label="`開啟作品 ${item.number} ${item.title}`" @click="dialogs?.open(item.id)" @keydown.enter="dialogs?.open(item.id)" @keydown.space.prevent="dialogs?.open(item.id)"><strong>{{item.rank}}</strong><span>作品 {{item.number}}・{{item.title}}</span><em><b>{{item.votes.toLocaleString('zh-TW')}}票</b></em></li></ol></div></div>
      <p class="results-updated">即時排名非最終結果，最終獲獎以主辦單位公告為準。<span class="summary-timestamp">最後更新：<time>{{results?.generatedAt??'讀取中'}}</time></span></p>
    </section>
  </main>
  <VotingDialogs v-if="bootstrap" ref="dialogs" :data="bootstrap" @updated="updateBootstrap" @results-changed="refreshResults" />
  <a class="back-to-top" href="#top" aria-label="回到頁面頂端"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 19V5M6.5 10.5 12 5l5.5 5.5"/></svg></a>
  <footer class="site-footer"><div class="footer-item footer-organization"><span>主辦單位</span><img :src="assetPath('images/主辦單位.png')" alt="農業部農村發展及水土保持署"></div><div class="footer-item footer-organization"><span>執行單位</span><img :src="assetPath('images/執行單位.png')" alt="台灣水資源與農業研究院"></div><p class="footer-copyright">Copyright © 2026 All Rights Reserved.</p></footer>
</template>
