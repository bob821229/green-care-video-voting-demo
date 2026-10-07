<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { api } from './api'
import { loadBootstrap } from './deviceContext'
import { assetPath, homePath, resultsPath } from './paths'
import VotingDialogs from './VotingDialogs.vue'
import type { Bootstrap, Category, Results } from './types'

const data=ref<Results|null>(null),bootstrap=ref<Bootstrap|null>(null),loadError=ref(''),menuOpen=ref(false)
const dialogs=ref<InstanceType<typeof VotingDialogs>>()
let refreshTimer:number|undefined
const heading=computed(()=>data.value?.live?'即時排名結果':'最終票選結果')
const formatNumber=(value:number)=>value.toLocaleString('zh-TW')
const formatDateTime=(value?:string)=>value?new Intl.DateTimeFormat('zh-TW',{dateStyle:'long',timeStyle:'short',timeZone:'Asia/Taipei'}).format(new Date(value)):'讀取中'
const groupName=(category:Category)=>category==='individual'?'個人組':'團體組'
const laurel=(category:Category)=>assetPath(`images/${category==='individual'?'laurel-individual':'laurel-team'}.svg`)
const homeUrl=homePath(),resultsUrl=resultsPath()
async function openWork(id:number){
  try{
    if(!bootstrap.value){bootstrap.value=await loadBootstrap();await nextTick()}
    await dialogs.value?.open(id)
  }catch(error){loadError.value=error instanceof Error?error.message:'作品資料暫時無法載入。'}
}
function updateBootstrap(value:Bootstrap){bootstrap.value=value}
async function refresh(){try{data.value=await api<Results>('/api/results');loadError.value=''}catch(error){loadError.value=error instanceof Error?error.message:'票選結果暫時無法載入。'}}
onMounted(async()=>{document.title='票選結果｜短片票選';await refresh();refreshTimer=window.setInterval(refresh,30000)})
onBeforeUnmount(()=>{if(refreshTimer)window.clearInterval(refreshTimer)})
</script>

<template>
  <header id="top" class="result-hero">
    <nav class="nav" aria-label="主要導覽">
      <a class="brand" :href="homeUrl" aria-label="綠色照顧－回到首頁"><img class="brand-logo" :src="assetPath('images/logo.png')" alt="綠色照顧"></a>
      <button class="nav-toggle" type="button" :aria-expanded="menuOpen" aria-controls="resultMenu" :aria-label="menuOpen?'關閉選單':'開啟選單'" @click="menuOpen=!menuOpen"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16"/></svg></button>
      <div id="resultMenu" class="nav-menu" :class="{open:menuOpen}"><a :href="`${homeUrl}#works`">參賽作品</a><a :href="`${homeUrl}#rules`">投票辦法</a><a class="current" :href="resultsUrl" aria-current="page">票選結果</a></div>
    </nav>
    <div class="hero-art-stage">
      <picture class="hero-official-art" aria-hidden="true">
        <source media="(max-width: 800px)" :srcset="assetPath('assets/campaign/banner/hero-mobile-title.svg')">
        <img :src="assetPath('assets/campaign/banner/hero-desktop-title.svg')" alt="">
      </picture>
      <h1 class="visually-hidden">綠照好時光－短影音競賽網路人氣票選結果</h1>
    </div>
  </header>

  <main class="results-main">
    <section v-if="loadError" class="results-unavailable" role="alert"><p class="eyebrow">結果暫時無法載入</p><h2>請稍後再試</h2><p>{{loadError}}</p><a class="primary-link" href="/">返回投票首頁</a></section>
    <template v-else-if="data">
      <section class="final-results" aria-labelledby="resultsPageHeading">
        <div class="final-results-heading"><h2 id="resultsPageHeading">{{heading}}</h2><p>最後更新：<time :datetime="data.generatedAt">{{formatDateTime(data.generatedAt)}}</time><br>即時排名非最終結果，以主辦單位公告為準</p></div>
        <div class="final-results-columns">
          <section v-for="category in (['individual','team'] as Category[])" :key="category" class="final-group" :class="`final-group-${category}`" :aria-labelledby="`${category}ResultTitle`">
            <h3 :id="`${category}ResultTitle`" class="visually-hidden">{{groupName(category)}}票選結果</h3>
            <article v-if="data.groups[category][0]" class="final-winner result-work-link" role="link" tabindex="0" :aria-label="`開啟作品 ${data.groups[category][0].number} ${data.groups[category][0].title}`" @click="openWork(data.groups[category][0].id)" @keydown.enter="openWork(data.groups[category][0].id)" @keydown.space.prevent="openWork(data.groups[category][0].id)">
              <div class="final-winner-poster"><img :src="assetPath(data.groups[category][0].poster)" alt="" loading="lazy"></div>
              <div class="final-winner-copy"><div class="final-winner-award"><img class="winner-laurel winner-laurel-left" :src="laurel(category)" alt="" aria-hidden="true"><div class="final-winner-award-copy"><span>{{groupName(category)}}</span><strong>第一名</strong></div><img class="winner-laurel winner-laurel-right" :src="laurel(category)" alt="" aria-hidden="true"></div><p>作品 {{data.groups[category][0].number}}</p><h4>{{data.groups[category][0].title}}</h4><small>{{data.groups[category][0].team}}</small><b>{{formatNumber(data.groups[category][0].votes)}}<span>票</span></b></div>
            </article>
            <div class="final-ranking-table"><div class="final-ranking-head" aria-hidden="true"><span>名次</span><span>作品</span><span>票數</span></div><ol><li v-for="item in data.groups[category].slice(1)" :key="item.id" class="result-work-link" role="link" tabindex="0" :aria-label="`開啟作品 ${item.number} ${item.title}`" @click="openWork(item.id)" @keydown.enter="openWork(item.id)" @keydown.space.prevent="openWork(item.id)"><strong>{{item.rank}}</strong><span><b>{{item.number}}｜{{item.title}}</b><small>{{item.team}}</small></span><em>{{formatNumber(item.votes)}}票</em></li></ol></div>
          </section>
        </div>
      </section>
    </template>
  </main>
  <VotingDialogs v-if="bootstrap" ref="dialogs" :data="bootstrap" @updated="updateBootstrap" @results-changed="refresh" />
  <a class="back-to-top" href="#top" aria-label="回到頁面頂端"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 19V5M6.5 10.5 12 5l5.5 5.5"/></svg></a>
  <footer class="site-footer"><div class="footer-item footer-organization"><span>主辦單位</span><img :src="assetPath('images/主辦單位.png')" alt="農業部農村發展及水土保持署"></div><div class="footer-item footer-organization"><span>執行單位</span><img :src="assetPath('images/執行單位.png')" alt="台灣水資源與農業研究院"></div><p class="footer-copyright">Copyright © 2026 All Rights Reserved.</p></footer>
</template>
