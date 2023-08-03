import WebGLContext from "./webgl.ts";
import loadImage from "./util/loadImage.ts";

import vertex from './vertex.glsl';
import fragment from './fragment.glsl';
import img0 from './assets/scene-2.jpg';


const canvas: HTMLCanvasElement = document.querySelector('canvas');
const webglContext = new WebGLContext(canvas);

loadImage(img0)
  .then((image: HTMLImageElement) => {
    webglContext.resize(image.width / 2, image.height);
    webglContext.initScene(vertex, fragment);
    webglContext.drawImage(image);
  });
