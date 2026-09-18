export const demoMode=import.meta.env.VITE_DEMO_MODE==='true'
export const appBase=import.meta.env.BASE_URL

export function assetPath(path:string){
  return `${appBase}${path.replace(/^\/+/, '')}`
}

export function homePath(workId?:number){
  const query=workId?`?work=${encodeURIComponent(workId)}`:''
  return `${appBase}${query}${workId?'#works':''}`
}

export function resultsPath(){
  return demoMode?`${appBase}?page=results`:`${appBase}results`
}
