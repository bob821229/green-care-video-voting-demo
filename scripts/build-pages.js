import {cp,copyFile,mkdir,rm,writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';

const root=resolve(import.meta.dirname,'..');
const output=resolve(root,'dist');

await rm(output,{recursive:true,force:true});
await mkdir(output,{recursive:true});
await cp(resolve(root,'public'),output,{recursive:true});
await copyFile(resolve(root,'videos.json'),resolve(output,'mock-videos.json'));
await writeFile(resolve(output,'.nojekyll'),'');
await rm(resolve(output,'admin.html'),{force:true});
await rm(resolve(output,'admin.js'),{force:true});
console.log(`GitHub Pages build created at ${output}`);
