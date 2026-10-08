import type { Category } from './types'

type WorkNumberSource = { id:number; number:string; category:Category }

export function displayWorkNumber(work:WorkNumberSource,catalog:WorkNumberSource[]){
  const group=catalog.filter(item=>item.category===work.category).sort((left,right)=>left.id-right.id)
  const index=group.findIndex(item=>item.id===work.id)
  return index>=0?String(index+1).padStart(2,'0'):work.number
}
