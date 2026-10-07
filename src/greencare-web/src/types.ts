export type Category = 'individual' | 'team'
export type Video = { id:number; number:string; title:string; team:string; youtubeId:string; poster:string; category:Category }
export type Vote = { id:number; videoId:number; category:Category; status:string; createdAtUtc:string; canCancel:boolean }
export type WatchProgress = { videoId:number; ratio:number; qualified:boolean|number }
export type Bootstrap = {
  videos:Video[]
  votes:Vote[]
  progress:WatchProgress[]
  limits:Record<Category,number>
  remaining:Record<Category,number>
  allowVoteCancellation:boolean
  activity:{state:string;startsAt:string;endsAt:string}
  recaptchaSiteKey:string
  demo:boolean
}
export type RankedVideo = Video & { votes:number; rank:number }
export type Results = {
  published:boolean
  live:boolean
  generatedAt:string
  activity:{state:string;startsAt:string;endsAt:string}
  groups:Record<Category,RankedVideo[]>
}
