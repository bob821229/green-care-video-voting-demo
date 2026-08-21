const {api}=window.votingApi;
const state={data:null,category:'individual'};
const $=(selector)=>document.querySelector(selector);
const esc=(value)=>String(value??'').replace(/[&<>'"]/g,(char)=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[char]));
const number=(value)=>new Intl.NumberFormat('zh-TW').format(value);
const percent=(value)=>new Intl.NumberFormat('zh-TW',{minimumFractionDigits:1,maximumFractionDigits:1}).format(value);
const dateTime=(value)=>new Intl.DateTimeFormat('zh-TW',{dateStyle:'long',timeStyle:'short'}).format(new Date(value));

async function loadResults(){return api('/api/results')}

function poster(video){return video.poster||`https://i.ytimg.com/vi/${encodeURIComponent(video.youtubeId)}/hqdefault.jpg`}
function resultCard(video,totalVotes){
  const ratio=totalVotes?video.votes/totalVotes*100:0;
  return `<article class="result-card rank-${video.rank}">
    <div class="rank-badge"><span>第</span><strong>${video.rank}</strong><span>名</span></div>
    <a class="result-poster" href="https://www.youtube.com/watch?v=${encodeURIComponent(video.youtubeId)}" target="_blank" rel="noopener noreferrer" aria-label="在 YouTube 觀看${esc(video.title)}">
      <img src="${esc(poster(video))}" alt="" loading="lazy"><span class="play-mark" aria-hidden="true"></span>
    </a>
    <div class="result-card-copy"><span class="video-number">作品 ${esc(video.number)}</span><h3>${esc(video.title)}</h3><p>${esc(video.team)}</p><div class="vote-total"><strong>${number(video.votes)}</strong><span>票</span><em>${percent(ratio)}%</em></div><div class="result-meter" role="progressbar" aria-label="得票率 ${percent(ratio)}%" aria-valuenow="${ratio}" aria-valuemin="0" aria-valuemax="100"><span style="width:${ratio}%"></span></div></div>
  </article>`;
}

function render(){
  const items=state.data.groups[state.category];
  const isIndividual=state.category==='individual';
  const totalVotes=items.reduce((sum,item)=>sum+item.votes,0);
  $('#rankingTitle').textContent=`${isIndividual?'個人組':'團體組'}票選結果`;
  $('#rankingPanel').setAttribute('aria-labelledby',isIndividual?'resultIndividualTab':'resultTeamTab');
  $('#topResults').innerHTML=items.slice(0,5).map((item)=>resultCard(item,totalVotes)).join('');
  $('#otherResultsList').innerHTML=items.slice(5).map((item)=>`<li><span class="list-rank">${item.rank}</span><span class="list-number">${esc(item.number)}</span><span class="list-name"><strong>${esc(item.title)}</strong><small>${esc(item.team)}</small></span><span class="list-votes">${number(item.votes)} 票</span></li>`).join('');
}

document.querySelectorAll('.result-tabs .category-tab').forEach((tab)=>tab.addEventListener('click',()=>{
  document.querySelectorAll('.result-tabs .category-tab').forEach((item)=>{const selected=item===tab;item.classList.toggle('active',selected);item.setAttribute('aria-selected',String(selected))});
  state.category=tab.dataset.category;
  render();
}));

try{
  state.data=await loadResults();
  $('#resultPeriod').textContent=`投票期間：${dateTime(state.data.activity?.startsAt)}－${dateTime(state.data.activity?.endsAt)}`;
  if(!state.data.published&&!state.data.preview){
    $('#resultsUnavailable').hidden=false;
    $('#unavailableMessage').textContent=state.data.message;
    $('#resultLead').textContent='正式結果將在票數確認完成後公布。';
  }else{
    $('#resultsContent').hidden=false;
    $('#previewNotice').hidden=!state.data.preview;
    $('#resultLead').textContent=state.data.preview?'目前為結果頁版型預覽。':'感謝每一位參與者對參賽作品的支持。';
    render();
  }
}catch(error){
  $('#resultsUnavailable').hidden=false;
  $('#unavailableMessage').textContent=error.message;
  $('#resultLead').textContent='目前無法讀取票選結果。';
}
