import WebGLContext from "./webgl.ts";
import loadImage from "./util/loadImage.ts";

import vertex from './vertex.glsl';
import fragment from './fragment.glsl';
// import img0 from './assets/scene-0.low.jpg';
import img0 from './assets/scene-0.jpg';

const canvasScale = 0.15;

const canvas: HTMLCanvasElement = document.querySelector('canvas');
const webglContext = new WebGLContext(canvas);

loadImage(img0)
  .then((image: HTMLImageElement) => {
    webglContext.resize(image.width * 0.5 * canvasScale, image.height * canvasScale);
    webglContext.initScene(vertex, fragment);
    webglContext.drawImage(image);
  });
