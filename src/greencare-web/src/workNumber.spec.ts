import { describe, expect, it } from 'vitest'
import { displayWorkNumber } from './workNumber'
import type { Video } from './types'

const videos:Video[]=[
  {id:1,number:'01',title:'個人作品',team:'個人單位',youtubeId:'a',poster:'a.jpg',category:'individual'},
  {id:13,number:'13',title:'個人作品末筆',team:'個人單位',youtubeId:'b',poster:'b.jpg',category:'individual'},
  {id:14,number:'14',title:'團體作品',team:'團體單位',youtubeId:'c',poster:'c.jpg',category:'team'},
  {id:27,number:'27',title:'團體作品末筆',team:'團體單位',youtubeId:'d',poster:'d.jpg',category:'team'},
]

describe('displayWorkNumber',()=>{
  it('numbers each category independently without changing database ids',()=>{
    expect(displayWorkNumber(videos[0],videos)).toBe('01')
    expect(displayWorkNumber(videos[1],videos)).toBe('02')
    expect(displayWorkNumber(videos[2],videos)).toBe('01')
    expect(displayWorkNumber(videos[3],videos)).toBe('02')
    expect(videos.map(video=>video.id)).toEqual([1,13,14,27])
  })
})
