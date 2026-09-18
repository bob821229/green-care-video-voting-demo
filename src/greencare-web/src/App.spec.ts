import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import App from './App.vue'

const videos = Array.from({ length: 30 }, (_, index) => ({ id:index+1, number:String(index+1).padStart(2,'0'), title:`作品 ${index+1}`, team:`參賽者 ${index+1}`, youtubeId:'video', poster:index<15?'images/posters/individual-demo.jpg':'images/posters/team-demo.jpg', category:index<15?'individual':'team' }))
const ranked = (category:'individual'|'team') => videos.filter(video=>video.category===category).map((video,index)=>({...video,votes:index===0?12:index===1?8:0,rank:index+1}))

describe('App',()=>{
  afterEach(()=>vi.unstubAllGlobals())

  it('renders the campaign home and switches the 15-work group',async()=>{
    vi.stubGlobal('fetch',vi.fn()
      .mockResolvedValueOnce({ok:true,json:async()=>({videos,votes:[],progress:[],remaining:{individual:2,team:2}})})
      .mockResolvedValueOnce({ok:true,json:async()=>({generatedAt:'2026-09-18T00:00:00Z',groups:{individual:ranked('individual'),team:ranked('team')}})}))
    const wrapper=mount(App)
    await flushPromises()
    expect(wrapper.get('h1').text()).toContain('綠照好時光')
    expect(wrapper.get('.hero-official-art img').attributes('src')).toBe('/assets/campaign/banner/hero-desktop-title.svg')
    expect(wrapper.get('.hero-official-art source').attributes('srcset')).toBe('/assets/campaign/banner/hero-mobile-title.svg')
    expect(wrapper.get('.hero-official-art source').attributes('media')).toBe('(max-width: 800px)')
    expect(wrapper.findAll('.video-card')).toHaveLength(15)
    expect(wrapper.get('.video-card h3').text()).toBe('作品 1')
    expect(wrapper.get('.summary-list li>span').text()).toBe('作品 01・作品 1')
    expect(wrapper.get('.summary-list li>em').text()).toBe('12票60.0%')
    await wrapper.get('#teamTab').trigger('click')
    expect(wrapper.findAll('.video-card')).toHaveLength(15)
    expect(wrapper.get('.video-card h3').text()).toBe('作品 16')
    expect(wrapper.get('#teamTab').attributes('aria-selected')).toBe('true')
  })

  it('opens the mobile navigation with accessible state',async()=>{
    vi.stubGlobal('fetch',vi.fn().mockResolvedValue({ok:false}))
    const wrapper=mount(App)
    await wrapper.get('.nav-toggle').trigger('click')
    expect(wrapper.get('.nav-toggle').attributes('aria-expanded')).toBe('true')
    expect(wrapper.get('#mainMenu').classes()).toContain('open')
  })
})
