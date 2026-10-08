import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import App from './App.vue'

const videos = Array.from({ length: 27 }, (_, index) => ({ id:index+1, number:String(index+1).padStart(2,'0'), title:`作品 ${index+1}`, team:`參賽者 ${index+1}`, youtubeId:'video', poster:index<13?'images/posters/individual-demo.jpg':'images/posters/team-demo.jpg', category:index<13?'individual':'team' }))
const ranked = (category:'individual'|'team') => videos.filter(video=>video.category===category).map((video,index)=>({...video,votes:index===0?12:index===1?8:0,rank:index+1}))

describe('App',()=>{
  afterEach(()=>vi.unstubAllGlobals())

  it('renders the campaign home and switches dynamic work groups',async()=>{
    vi.stubGlobal('fetch',vi.fn()
      .mockResolvedValueOnce({ok:true,json:async()=>({videos,votes:[],progress:[],remaining:{individual:2,team:2}})})
      .mockResolvedValueOnce({ok:true,json:async()=>({generatedAt:'2026-09-18T00:00:00Z',groups:{individual:ranked('individual'),team:ranked('team')}})}))
    const wrapper=mount(App)
    await flushPromises()
    expect(wrapper.get('h1').text()).toContain('綠照好時光')
    expect(wrapper.get('.hero-official-art img').attributes('src')).toBe('/assets/campaign/banner/hero-desktop-title.webp')
    expect(wrapper.get('.hero-official-art source').attributes('srcset')).toBe('/assets/campaign/banner/hero-mobile-title.webp')
    expect(wrapper.get('.hero-official-art source').attributes('media')).toBe('(max-width: 800px)')
    expect(wrapper.findAll('.video-card')).toHaveLength(13)
    expect(wrapper.get('#individualTab small').text()).toBe('13 支初賽入圍')
    expect(wrapper.get('.video-card .video-number').text()).toBe('01')
    expect(wrapper.get('.video-card h3').text()).toBe('作品 1')
    expect(wrapper.get('.video-card .team').text()).toBe('參賽者 1')
    expect(wrapper.get('.summary-list li>span').text()).toBe('作品 01・作品 1')
    expect(wrapper.get('.summary-list li>em').text()).toBe('12票')
    expect(wrapper.find('.summary-list li>em small').exists()).toBe(false)
    await wrapper.get('#teamTab').trigger('click')
    expect(wrapper.findAll('.video-card')).toHaveLength(14)
    expect(wrapper.get('#teamTab small').text()).toBe('14 支初賽入圍')
    expect(wrapper.get('.video-card .video-number').text()).toBe('01')
    expect(wrapper.get('.video-card h3').text()).toBe('作品 14')
    expect(wrapper.get('#teamTab').attributes('aria-selected')).toBe('true')
    expect(wrapper.get('#videoGrid').attributes('data-category')).toBe('team')
  })

  it('opens the mobile navigation with accessible state',async()=>{
    vi.stubGlobal('fetch',vi.fn().mockResolvedValue({ok:false}))
    const wrapper=mount(App)
    await wrapper.get('.nav-toggle').trigger('click')
    expect(wrapper.get('.nav-toggle').attributes('aria-expanded')).toBe('true')
    expect(wrapper.get('#mainMenu').classes()).toContain('open')
  })
})
