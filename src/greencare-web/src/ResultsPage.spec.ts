import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import ResultsPage from './ResultsPage.vue'
import type { Category, Results } from './types'

const group=(category:Category,start:number)=>Array.from({length:15},(_,index)=>({id:start+index,number:String(start+index).padStart(2,'0'),title:`作品 ${start+index}`,team:`參賽單位 ${start+index}`,youtubeId:'video',poster:category==='individual'?'images/posters/individual-demo.jpg':'images/posters/team-demo.jpg',category,votes:15-index,rank:index+1}))
const results:Results={published:false,live:true,generatedAt:'2026-09-18T04:00:00Z',activity:{state:'active',startsAt:'2026-10-12T02:00:00Z',endsAt:'2026-10-23T09:00:00Z'},groups:{individual:group('individual',1),team:group('team',16)}}

describe('ResultsPage',()=>{
  afterEach(()=>{vi.unstubAllGlobals();vi.useRealTimers()})
  it('renders both winners and all ranked works from the results API',async()=>{
    vi.stubGlobal('fetch',vi.fn().mockResolvedValue({ok:true,json:async()=>results}))
    const wrapper=mount(ResultsPage)
    await flushPromises()
    expect(wrapper.get('#resultsPageHeading').text()).toBe('即時排名結果')
    expect(wrapper.findAll('.final-winner')).toHaveLength(2)
    expect(wrapper.findAll('.final-ranking-table li')).toHaveLength(28)
    expect(wrapper.find('.final-winner-copy h4').text()).toBe('作品 1')
    expect(wrapper.text()).not.toContain('每 30 秒更新')
  })

  it('shows a recoverable error state when results cannot load',async()=>{
    vi.stubGlobal('fetch',vi.fn().mockResolvedValue({ok:false,status:503,json:async()=>({error:'結果服務暫時無法使用。'})}))
    const wrapper=mount(ResultsPage)
    await flushPromises()
    expect(wrapper.get('[role="alert"]').text()).toContain('結果服務暫時無法使用。')
    expect(wrapper.get('[role="alert"] a').attributes('href')).toBe('/')
  })

  it('refreshes results every 30 seconds',async()=>{
    vi.useFakeTimers()
    const fetchMock=vi.fn().mockResolvedValue({ok:true,json:async()=>results})
    vi.stubGlobal('fetch',fetchMock)
    const wrapper=mount(ResultsPage)
    await flushPromises()
    expect(fetchMock).toHaveBeenCalledTimes(1)
    await vi.advanceTimersByTimeAsync(30000)
    await flushPromises()
    expect(fetchMock).toHaveBeenCalledTimes(2)
    wrapper.unmount()
  })
})
