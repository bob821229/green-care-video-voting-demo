import { beforeEach, describe, expect, it, vi } from 'vitest'
import { demoApi } from './demoApi'
import type { Bootstrap, Results, Vote } from './types'

const videos=Array.from({length:30},(_,index)=>({id:index+1,number:String(index+1).padStart(2,'0'),title:`作品 ${index+1}`,team:`參賽者 ${index+1}`,youtubeId:'demo',poster:'images/posters/individual-demo.jpg'}))

describe('GitHub Pages demo API',()=>{
  beforeEach(()=>{
    localStorage.clear()
    vi.stubGlobal('fetch',vi.fn().mockResolvedValue({ok:true,json:async()=>videos}))
  })

  it('loads 30 works without a backend',async()=>{
    const data=await demoApi<Bootstrap>('/api/bootstrap')
    expect(data.demo).toBe(true)
    expect(data.videos).toHaveLength(30)
    expect(data.remaining).toEqual({individual:2,team:2})
  })

  it('persists a qualified vote and reflects it in results',async()=>{
    localStorage.setItem('greencare-vue-demo-v2',JSON.stringify({votes:[],progress:[{videoId:1,ratio:.8,qualified:true}]}))
    const vote=await demoApi<Vote>('/api/votes',{method:'POST',body:JSON.stringify({videoId:1})})
    expect(vote.videoId).toBe(1)
    const bootstrap=await demoApi<Bootstrap>('/api/bootstrap')
    expect(bootstrap.remaining.individual).toBe(1)
    const results=await demoApi<Results>('/api/results')
    expect(results.groups.individual.find(item=>item.id===1)?.votes).toBe(16)
  })

  it('does not count playback while the page is hidden',async()=>{
    const {sessionId}=await demoApi<{sessionId:string}>('/api/watch/start',{method:'POST',body:JSON.stringify({videoId:1,duration:100})})
    const report=(position:number,visible:boolean)=>demoApi<{ratio:number}>('/api/watch/progress',{method:'POST',body:JSON.stringify({sessionId,position,playbackRate:1,playing:true,visible,event:'tick'})})

    expect((await report(5,true)).ratio).toBeCloseTo(.05)
    expect((await report(50,false)).ratio).toBeCloseTo(.05)
    expect((await report(55,false)).ratio).toBeCloseTo(.05)
    expect((await report(55,true)).ratio).toBeCloseTo(.05)
    expect((await report(60,true)).ratio).toBeCloseTo(.1)
  })
})
