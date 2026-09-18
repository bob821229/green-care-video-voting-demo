import { demoApi } from './demoApi'
import { demoMode } from './paths'

export async function api<T>(url:string, init?:RequestInit):Promise<T>{
  if(demoMode)return demoApi<T>(url,init)
  const response=await fetch(url,{...init,headers:{'Content-Type':'application/json',...(init?.headers??{})}})
  const body=await response.json().catch(()=>({})) as {error?:string}
  if(!response.ok)throw new Error(body.error||`請求失敗（${response.status}）`)
  return body as T
}
