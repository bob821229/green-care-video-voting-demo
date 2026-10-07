import { api } from './api'
import type { Bootstrap } from './types'

export function deviceSignal(){
  return [
    navigator.platform,
    navigator.language,
    screen.width,
    screen.height,
    Intl.DateTimeFormat().resolvedOptions().timeZone
  ].join('|')
}

export function loadBootstrap(){
  return api<Bootstrap>('/api/bootstrap',{headers:{'X-Device-Signal':deviceSignal()}})
}
