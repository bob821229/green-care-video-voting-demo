import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import VotingDialogs from './VotingDialogs.vue'
import type { Bootstrap, Video } from './types'

const videos:Video[] = Array.from({length:27},(_,index)=>({id:index+1,number:String(index+1).padStart(2,'0'),title:`作品 ${index+1}`,team:`參賽者 ${index+1}`,youtubeId:'video',poster:'poster.jpg',category:index<13?'individual':'team'}))
const base:Bootstrap={videos,votes:[],progress:[{videoId:1,ratio:.85,qualified:true}],limits:{individual:2,team:2},remaining:{individual:2,team:2},allowVoteCancellation:false,activity:{state:'active',startsAt:'2026-01-01',endsAt:'2026-12-31'},recaptchaSiteKey:'',demo:false}

beforeAll(()=>{
  HTMLDialogElement.prototype.showModal=vi.fn(function(this:HTMLDialogElement){this.setAttribute('open','')})
  HTMLDialogElement.prototype.close=vi.fn(function(this:HTMLDialogElement){this.removeAttribute('open')})
})

describe('VotingDialogs',()=>{
  afterEach(()=>{vi.useRealTimers();vi.unstubAllGlobals();localStorage.clear();delete window.grecaptcha;delete window.YT;document.querySelectorAll('script[data-recaptcha-api]').forEach(script=>script.remove())})

  it('waits for YouTube to report a valid duration before starting a watch session',async()=>{
    vi.useFakeTimers()
    const fetchMock=vi.fn().mockResolvedValue({ok:true,status:200,json:async()=>({sessionId:'watch-session'})})
    vi.stubGlobal('fetch',fetchMock)
    const getDuration=vi.fn().mockReturnValueOnce(0).mockReturnValueOnce(0).mockReturnValue(76)
    window.YT={
      PlayerState:{PLAYING:1},
      Player:vi.fn(function(_host:HTMLElement,options:{events:{onReady:()=>void}}){
        const instance={getDuration,getCurrentTime:()=>0,getPlaybackRate:()=>1,destroy:vi.fn()}
        window.setTimeout(options.events.onReady,0)
        return instance
      })
    }
    const wrapper=mount(VotingDialogs,{props:{data:structuredClone(base)}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(2)
    await vi.advanceTimersByTimeAsync(1100)
    await flushPromises()

    expect(getDuration).toHaveBeenCalledTimes(3)
    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(fetchMock).toHaveBeenCalledWith('/api/watch/start',expect.objectContaining({
      method:'POST',
      body:JSON.stringify({videoId:2,duration:76})
    }))
    expect(wrapper.get('.message').text()).toBe('')
  })

  it('retries watch session initialization when playback starts after duration loading timed out',async()=>{
    vi.useFakeTimers()
    const fetchMock=vi.fn().mockResolvedValue({ok:true,status:200,json:async()=>({sessionId:'watch-session'})})
    vi.stubGlobal('fetch',fetchMock)
    let duration=0
    let onStateChange:(event:{data:number})=>void=()=>{}
    window.YT={
      PlayerState:{PLAYING:1},
      Player:vi.fn(function(_host:HTMLElement,options:{events:{onReady:()=>void;onStateChange:(event:{data:number})=>void}}){
        onStateChange=options.events.onStateChange
        const instance={getDuration:()=>duration,getCurrentTime:()=>0,getPlaybackRate:()=>1,destroy:vi.fn()}
        window.setTimeout(options.events.onReady,0)
        return instance
      })
    }
    const wrapper=mount(VotingDialogs,{props:{data:structuredClone(base)}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(18)
    await vi.advanceTimersByTimeAsync(10000)
    await flushPromises()
    expect(fetchMock).not.toHaveBeenCalled()
    expect(wrapper.get('.message').text()).toContain('自動繼續嘗試')

    duration=76
    onStateChange({data:1})
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(fetchMock).toHaveBeenCalledWith('/api/watch/start',expect.objectContaining({body:JSON.stringify({videoId:18,duration:76})}))
    expect(wrapper.get('.message').text()).toBe('')
  })

  it('recovers duration initialization without requiring another playback-state event',async()=>{
    vi.useFakeTimers()
    const fetchMock=vi.fn().mockResolvedValue({ok:true,status:200,json:async()=>({sessionId:'watch-session'})})
    vi.stubGlobal('fetch',fetchMock)
    let duration=0
    window.YT={
      PlayerState:{PLAYING:1},
      Player:vi.fn(function(_host:HTMLElement,options:{events:{onReady:()=>void}}){
        const instance={getDuration:()=>duration,getCurrentTime:()=>0,getPlaybackRate:()=>1,getPlayerState:()=>1,destroy:vi.fn()}
        window.setTimeout(options.events.onReady,0)
        return instance
      })
    }
    const wrapper=mount(VotingDialogs,{props:{data:structuredClone(base)}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(19)
    await vi.advanceTimersByTimeAsync(10000)
    await flushPromises()
    expect(fetchMock).not.toHaveBeenCalled()

    duration=76
    await vi.advanceTimersByTimeAsync(1100)
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith('/api/watch/start',expect.objectContaining({body:JSON.stringify({videoId:19,duration:76})}))
    expect(wrapper.get('.message').text()).toBe('')
  })

  it('updates and stores client progress without waiting for a server progress response',async()=>{
    vi.useFakeTimers()
    const fetchMock=vi.fn().mockResolvedValueOnce({ok:true,status:200,json:async()=>({sessionId:'watch-session'})})
    vi.stubGlobal('fetch',fetchMock)
    let position=0
    window.YT={
      PlayerState:{PLAYING:1},
      Player:vi.fn(function(_host:HTMLElement,options:{events:{onReady:()=>void}}){
        const instance={getDuration:()=>89,getCurrentTime:()=>position,getPlaybackRate:()=>1,getPlayerState:()=>-1,destroy:vi.fn()}
        window.setTimeout(options.events.onReady,0)
        return instance
      })
    }
    const wrapper=mount(VotingDialogs,{props:{data:structuredClone(base)}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(14)
    await vi.advanceTimersByTimeAsync(0)
    await flushPromises()

    position=1
    await vi.advanceTimersByTimeAsync(1000)
    position=2
    await vi.advanceTimersByTimeAsync(3000)
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(wrapper.get('.progress-label strong').text()).not.toBe('0%')
    expect(localStorage.getItem('greencare-client-watch-v1')).toContain('"videoId":14')
  })
  it('keeps client progress running when server watch initialization fails',async()=>{
    vi.useFakeTimers()
    vi.stubGlobal('fetch',vi.fn().mockRejectedValue(new Error('network unavailable')))
    let position=0
    window.YT={
      PlayerState:{PLAYING:1},
      Player:vi.fn(function(_host:HTMLElement,options:{events:{onReady:()=>void}}){
        const instance={getDuration:()=>100,getCurrentTime:()=>position,getPlaybackRate:()=>1,getPlayerState:()=>1,destroy:vi.fn()}
        window.setTimeout(options.events.onReady,0)
        return instance
      })
    }
    const wrapper=mount(VotingDialogs,{props:{data:structuredClone(base)}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(15)
    await vi.advanceTimersByTimeAsync(0)
    await flushPromises()

    position=1
    await vi.advanceTimersByTimeAsync(1000)
    position=4
    await vi.advanceTimersByTimeAsync(3000)

    expect(wrapper.get('.progress-label strong').text()).not.toBe('0%')
    expect(localStorage.getItem('greencare-client-watch-v1')).toContain('"videoId":15')
    expect(wrapper.get('.message').text()).toContain('進度仍會保存在此瀏覽器')
  })
  it('continues accumulating valid seconds after reopening before the previous playback position',async()=>{
    vi.useFakeTimers()
    localStorage.setItem('greencare-client-watch-v1',JSON.stringify({15:{videoId:15,youtubeId:'video',duration:100,watchedSeconds:24,lastPosition:24,updatedAt:new Date().toISOString()}}))
    vi.stubGlobal('fetch',vi.fn().mockResolvedValue({ok:true,status:200,json:async()=>({sessionId:'watch-session'})}))
    let position=0
    window.YT={
      PlayerState:{PLAYING:1},
      Player:vi.fn(function(_host:HTMLElement,options:{events:{onReady:()=>void}}){
        const instance={getDuration:()=>100,getCurrentTime:()=>position,getPlaybackRate:()=>1,getPlayerState:()=>1,destroy:vi.fn()}
        window.setTimeout(options.events.onReady,0)
        return instance
      })
    }
    const wrapper=mount(VotingDialogs,{props:{data:structuredClone(base)}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(15)
    await vi.advanceTimersByTimeAsync(0)
    await flushPromises()
    expect(wrapper.get('.progress-label strong').text()).toBe('24%')

    position=1
    await vi.advanceTimersByTimeAsync(1000)
    position=2
    await vi.advanceTimersByTimeAsync(1000)

    expect(wrapper.get('.progress-label strong').text()).toBe('26%')
  })
  it('opens a qualified work with local captcha and an enabled vote action',async()=>{
    const wrapper=mount(VotingDialogs,{props:{data:structuredClone(base)}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(1)
    expect(wrapper.get('.watch-dialog').attributes()).toHaveProperty('open')
    expect(wrapper.get('.watch-heading h2').text()).toBe('作品 1')
    expect(wrapper.get('.watch-heading .watch-team').text()).toBe('參賽者 1')
    expect(wrapper.get('.progress-label strong').text()).toBe('85%')
    expect(wrapper.get('.demo-captcha').text()).toContain('本機開發驗證')
    expect(wrapper.get('.vote-button').attributes('disabled')).toBeUndefined()
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(14)
    expect(wrapper.get('.watch-heading .eyebrow').text()).toBe('團體組 01')
    expect(wrapper.get('.watch-heading .watch-team').text()).toBe('參賽者 14')
  })

  it('renders and reveals Google reCAPTCHA for a qualified production work',async()=>{
    const data=structuredClone(base)
    data.recaptchaSiteKey='production-site-key'
    const render=vi.fn(()=>7)
    window.grecaptcha={enterprise:{render,reset:vi.fn()}}
    const wrapper=mount(VotingDialogs,{props:{data}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(1)
    await flushPromises()
    expect(render).toHaveBeenCalledWith(expect.any(HTMLElement),expect.objectContaining({sitekey:'production-site-key',action:'vote'}))
    expect(wrapper.get('.recaptcha-box').classes()).toContain('captcha-visible')
  })

  it('requires visiting an existing vote before voting again when the group is full',async()=>{
    const data=structuredClone(base)
    data.allowVoteCancellation=true
    data.votes=[{id:11,videoId:2,category:'individual',status:'valid',createdAtUtc:'2026-09-18',canCancel:true},{id:12,videoId:3,category:'individual',status:'valid',createdAtUtc:'2026-09-18',canCancel:true}]
    data.remaining.individual=0
    const wrapper=mount(VotingDialogs,{props:{data}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(1)
    expect(wrapper.findAll('.replace-panel button')).toHaveLength(2)
    expect(wrapper.get('.replace-panel').text()).toContain('可先取消此瀏覽器投出的票')
    expect(wrapper.get('.vote-button').text()).toBe('請先取消一票')
    expect(wrapper.get('.vote-button').attributes()).toHaveProperty('disabled')
    expect(wrapper.find('.demo-captcha').isVisible()).toBe(false)
    await wrapper.findAll('.replace-panel button')[0].trigger('click')
    await flushPromises()
    expect(wrapper.get('.watch-heading h2').text()).toBe('作品 2')
  })

  it('clears captcha verification when navigating to another work',async()=>{
    const data=structuredClone(base)
    data.progress.push({videoId:2,ratio:.85,qualified:true})
    const wrapper=mount(VotingDialogs,{props:{data}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(1)
    const captcha=wrapper.get<HTMLInputElement>('.demo-captcha input')
    await captcha.setValue(true)
    expect(captcha.element.checked).toBe(true)
    await wrapper.findAll('.video-pagination button')[1].trigger('click')
    await flushPromises()
    expect(wrapper.get('.watch-heading h2').text()).toBe('作品 2')
    expect(wrapper.get<HTMLInputElement>('.demo-captcha input').element.checked).toBe(false)
  })

  it('confirms and submits a qualified development vote',async()=>{
    const refreshed=structuredClone(base)
    refreshed.votes=[{id:20,videoId:1,category:'individual',status:'valid',createdAtUtc:'2026-09-18',canCancel:true}]
    refreshed.remaining.individual=1
    const fetchMock=vi.fn()
      .mockResolvedValueOnce({ok:true,status:201,json:async()=>({id:20,status:'valid'})})
      .mockResolvedValueOnce({ok:true,status:200,json:async()=>refreshed})
    vi.stubGlobal('fetch',fetchMock)
    const wrapper=mount(VotingDialogs,{props:{data:structuredClone(base)}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(1)
    await wrapper.get('.demo-captcha input').setValue(true)
    await wrapper.get('.vote-button').trigger('click')
    expect(wrapper.get('.confirm-dialog').attributes()).toHaveProperty('open')
    await wrapper.get('.confirm-primary').trigger('click')
    await flushPromises()
    expect(fetchMock).toHaveBeenCalledWith('/api/votes',expect.objectContaining({method:'POST'}))
    expect(wrapper.emitted('updated')).toHaveLength(1)
    expect(wrapper.get('.message').text()).toContain('投票成功')
  })

  it('confirms and cancels an existing vote',async()=>{
    const data=structuredClone(base)
    data.allowVoteCancellation=true
    data.votes=[{id:41,videoId:1,category:'individual',status:'valid',createdAtUtc:'2026-09-18',canCancel:true}]
    data.remaining.individual=1
    const refreshed=structuredClone(base)
    const fetchMock=vi.fn()
      .mockResolvedValueOnce({ok:true,status:200,json:async()=>({ok:true})})
      .mockResolvedValueOnce({ok:true,status:200,json:async()=>refreshed})
    vi.stubGlobal('fetch',fetchMock)
    const wrapper=mount(VotingDialogs,{props:{data}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(1)
    await wrapper.get('.cancel-vote-button').trigger('click')
    await wrapper.get('.confirm-primary').trigger('click')
    await flushPromises()
    expect(fetchMock).toHaveBeenCalledWith('/api/votes/41',expect.objectContaining({method:'DELETE'}))
    expect(wrapper.get('.message').text()).toContain('已取消投票')
  })

  it('shows environment votes from another browser without allowing cancellation',async()=>{
    const data=structuredClone(base)
    data.allowVoteCancellation=true
    data.votes=[
      {id:51,videoId:1,category:'individual',status:'valid',createdAtUtc:'2026-09-18',canCancel:false},
      {id:52,videoId:2,category:'individual',status:'valid',createdAtUtc:'2026-09-18',canCancel:false}
    ]
    data.remaining.individual=0
    const wrapper=mount(VotingDialogs,{props:{data}})

    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(1)
    expect(wrapper.get('.vote-button').text()).toBe('已投票')
    expect(wrapper.find('.cancel-vote-button').exists()).toBe(false)

    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(3)
    expect(wrapper.get('.replace-panel').text()).toContain('請回到原投票瀏覽器取消')
    expect(wrapper.find('.replace-panel button').exists()).toBe(false)
  })

  it('hides cancellation and replacement controls when cancellation is disabled',async()=>{
    const data=structuredClone(base)
    data.votes=[
      {id:61,videoId:1,category:'individual',status:'valid',createdAtUtc:'2026-09-18',canCancel:false},
      {id:62,videoId:2,category:'individual',status:'valid',createdAtUtc:'2026-09-18',canCancel:false}
    ]
    data.progress.push({videoId:3,ratio:.85,qualified:true})
    data.remaining.individual=0
    const wrapper=mount(VotingDialogs,{props:{data}})

    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(1)
    expect(wrapper.find('.cancel-vote-button').exists()).toBe(false)

    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(3)
    expect(wrapper.get('.replace-panel').text()).toContain('無法取消或改投')
    expect(wrapper.find('.replace-panel button').exists()).toBe(false)
    expect(wrapper.get('.vote-button').text()).toBe('本組已投滿 2 票')
  })
})
