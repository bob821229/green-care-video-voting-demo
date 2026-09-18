import { createApp } from 'vue'
import '@fontsource-variable/noto-sans-tc'
import App from './App.vue'
import ResultsPage from './ResultsPage.vue'
import { demoMode } from './paths'

const path=location.pathname.replace(/\/$/,'')
const demoResults=demoMode&&new URLSearchParams(location.search).get('page')==='results'
if(demoMode)document.documentElement.dataset.demo='true'
createApp(demoResults||path==='/results'||path.endsWith('/results.html')?ResultsPage:App).mount('#app')
