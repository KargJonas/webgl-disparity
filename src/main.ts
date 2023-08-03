import WebGLContext from "./webgl.ts";
import loadImage from "./util/loadImage.ts";

import vertex from './vertex.glsl';
import fragment from './depth_map.glsl';
import img0 from './assets/scene-2.jpg';

const canvasWidth = 500;

const canvas: HTMLCanvasElement = document.querySelector('canvas');
const webglContext = new WebGLContext(canvas);

loadImage(img0)
  .then((image: HTMLImageElement) => {
    const ratio = image.height / (image.width / 2);
    webglContext.resize(canvasWidth, canvasWidth * ratio);
    webglContext.initScene(vertex, fragment);
    webglContext.drawImage(image);
  });
