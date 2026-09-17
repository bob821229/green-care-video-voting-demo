// 卡片與結果頁封面來源：
// 'youtube'  = 全部使用 YouTube 自動封面
// 'provided' = 優先使用 videos.json 的 poster，未提供時自動退回 YouTube 封面
window.siteConfig = {
  posterSource: 'youtube',
  winnerPosterSource: 'provided',
  youtubePosterQuality: 'maxresdefault',
  workSubtitle: '新北市淡水區忠寮社區'
};

const youtubePoster=(videoId,quality)=>`https://i.ytimg.com/vi/${encodeURIComponent(videoId)}/${quality}.jpg`;
window.posterTools={
  forVideo(video,source=window.siteConfig.posterSource){
    if(source==='provided'&&video.poster)return {src:video.poster,stage:'provided'};
    return {src:youtubePoster(video.youtubeId,window.siteConfig.youtubePosterQuality),stage:window.siteConfig.youtubePosterQuality};
  },
  fallback(event){
    const image=event.currentTarget,videoId=image.dataset.youtubeId,stage=image.dataset.posterStage;
    const next=stage==='provided'?'maxresdefault':stage==='maxresdefault'?'sddefault':stage==='sddefault'?'hqdefault':null;
    if(!next){image.removeEventListener('error',window.posterTools.fallback);return}
    image.dataset.posterStage=next;
    image.src=youtubePoster(videoId,next);
  },
  bind(root=document){
    root.querySelectorAll('img[data-youtube-id]').forEach(image=>image.addEventListener('error',window.posterTools.fallback));
  }
};
