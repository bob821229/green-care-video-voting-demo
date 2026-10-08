export const demoMode=import.meta.env.VITE_DEMO_MODE==='true'
export const appBase=import.meta.env.BASE_URL

export function assetPath(path:string){
  return `${appBase}${path.replace(/^\/+/, '')}`
}

function optimizedPoster(path:string,width:360|720|1080){
  return path.replace(/images\/posters\/official\/(\d+)\.jpg$/i,`images/posters/official/optimized/$1-${width}.webp`)
}

export function posterPath(path:string,width:360|720|1080=720){
  return assetPath(optimizedPoster(path,width))
}

export function posterSrcSet(path:string){
  if(!/images\/posters\/official\/\d+\.jpg$/i.test(path))return undefined
  return ([360,720,1080] as const).map(width=>`${posterPath(path,width)} ${width}w`).join(', ')
}

export function homePath(workId?:number){
  const query=workId?`?work=${encodeURIComponent(workId)}`:''
  return `${appBase}${query}${workId?'#works':''}`
}

export function resultsPath(){
  return demoMode?`${appBase}?page=results`:`${appBase}results`
}
