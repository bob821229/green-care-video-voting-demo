import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import VotingDialogs from './VotingDialogs.vue'
import type { Bootstrap, Video } from './types'

const videos:Video[] = Array.from({length:30},(_,index)=>({id:index+1,number:String(index+1).padStart(2,'0'),title:`作品 ${index+1}`,team:`參賽者 ${index+1}`,youtubeId:'video',poster:'poster.jpg',category:index<15?'individual':'team'}))
const base:Bootstrap={videos,votes:[],progress:[{videoId:1,ratio:.85,qualified:true}],limits:{individual:2,team:2},remaining:{individual:2,team:2},allowVoteCancellation:false,activity:{state:'active',startsAt:'2026-01-01',endsAt:'2026-12-31'},recaptchaSiteKey:'',demo:false}

beforeAll(()=>{
  HTMLDialogElement.prototype.showModal=vi.fn(function(this:HTMLDialogElement){this.setAttribute('open','')})
  HTMLDialogElement.prototype.close=vi.fn(function(this:HTMLDialogElement){this.removeAttribute('open')})
})

describe('VotingDialogs',()=>{
  afterEach(()=>{vi.unstubAllGlobals();delete window.grecaptcha;document.querySelectorAll('script[data-recaptcha-api]').forEach(script=>script.remove())})
  it('opens a qualified work with local captcha and an enabled vote action',async()=>{
    const wrapper=mount(VotingDialogs,{props:{data:structuredClone(base)}})
    await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(1)
    expect(wrapper.get('.watch-dialog').attributes()).toHaveProperty('open')
    expect(wrapper.get('.watch-heading h2').text()).toBe('作品 1')
    expect(wrapper.get('.progress-label strong').text()).toBe('85%')
    expect(wrapper.get('.demo-captcha').text()).toContain('本機開發驗證')
    expect(wrapper.get('.vote-button').attributes('disabled')).toBeUndefined()
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
