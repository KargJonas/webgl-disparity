const quad = [
  -1, -1,
  1, -1,
  -1, 1,
  1, -1,
  1, 1,
  -1, 1,
];

export default class WebGLContext {
  declare sizeUniformLocation: WebGLUniformLocation;
  declare positionBuffer: WebGLBuffer | null;
  declare cnv: HTMLCanvasElement;
  declare ctx: WebGL2RenderingContext;

  constructor(cnv: HTMLCanvasElement) {
    const ctx = cnv.getContext('webgl2');

    if (!ctx) throw 'Could not create WebGL context.';

    this.cnv = cnv;
    this.ctx = ctx;
  }

  resize(width: number, height: number) {
    const ctx = this.ctx;
    const cnv = this.cnv;

    cnv.width = width;
    cnv.height = height;

    // Update the WebGL viewport to match the new canvas size
    ctx.viewport(0, 0, cnv.width, cnv.height);

    // Update the quad vertices to match the new canvas size
    const scaledQuad = quad.map((coord) => (coord * 2) / Math.max(cnv.width, cnv.height));

    ctx.bindBuffer(ctx.ARRAY_BUFFER, this.positionBuffer);
    ctx.bufferData(ctx.ARRAY_BUFFER, new Float32Array(scaledQuad), ctx.STATIC_DRAW);
  }

  private createShader(ctx: WebGL2RenderingContext, type: number, shaderCode: string): WebGLShader {
    // Create a shader
    const shader: WebGLShader | null = ctx.createShader(type);

    if (!shader) throw 'Failed to create shader.';

    // Set source of shader code and compile it
    ctx.shaderSource(shader, shaderCode);
    ctx.compileShader(shader);

    // Handle shader compile errors.
    if (!ctx.getShaderParameter(shader, ctx.COMPILE_STATUS)) {
      console.warn('Error compiling shader:');
      throw ctx.getShaderInfoLog(shader);
    }

    return shader;
  }

  private createProgram(
    ctx: WebGL2RenderingContext,
    vertexShader: WebGLShader,
    fragmentShader: WebGLShader
  ): WebGLProgram {

    // Create a shader program
    const program: WebGLProgram | null = ctx.createProgram();

    if (!program) throw 'Failed to create shader program';

    // Attach shaders and link program
    ctx.attachShader(program, vertexShader);
    ctx.attachShader(program, fragmentShader);
    ctx.linkProgram(program);

    // Handle failed attaching of shaders to shader program
    if (!ctx.getProgramParameter(program, ctx.LINK_STATUS)) {
      console.warn('Error linking program:');
      throw ctx.getProgramInfoLog(program);
    }

    return program;
  }

  initScene(vertexShaderSource: string, fragmentShaderSource: string) {
    const ctx = this.ctx;

    if (!ctx) {
      console.error('WebGL not supported');
      return;
    }

    // Create the vertex shader and fragment shader
    const vertexShader = this.createShader(ctx, ctx.VERTEX_SHADER, vertexShaderSource);
    const fragmentShader = this.createShader(ctx, ctx.FRAGMENT_SHADER, fragmentShaderSource);

    // Create the WebGL program
    const program = this.createProgram(ctx, vertexShader, fragmentShader);

    ctx.useProgram(program);

    // Set up the quad (two triangles) that will cover the whole canvas
    const positionAttributeLocation = ctx.getAttribLocation(program, 'a_position');
    this.positionBuffer = ctx.createBuffer();
    ctx.bindBuffer(ctx.ARRAY_BUFFER, this.positionBuffer);
    ctx.bufferData(ctx.ARRAY_BUFFER, new Float32Array(quad), ctx.STATIC_DRAW);
    ctx.enableVertexAttribArray(positionAttributeLocation);
    ctx.vertexAttribPointer(positionAttributeLocation, 2, ctx.FLOAT, false, 0, 0);

    // Set up the uniform for the texture
    const imageUniformLocation = ctx.getUniformLocation(program, 'u_image');
    ctx.uniform1i(imageUniformLocation, 0);

    // Set up the uniform for the texture size
    this.sizeUniformLocation = ctx.getUniformLocation(program, 'u_size')!;
  }

  drawImage(image: HTMLImageElement) {
    const ctx = this.ctx;
    const texture = ctx.createTexture();

    ctx.uniform2f(this.sizeUniformLocation, image.width, image.height);

    ctx.bindTexture(ctx.TEXTURE_2D, texture);
    ctx.texImage2D(ctx.TEXTURE_2D, 0, ctx.RGBA, ctx.RGBA, ctx.UNSIGNED_BYTE, image);
    ctx.texParameteri(ctx.TEXTURE_2D, ctx.TEXTURE_WRAP_S, ctx.CLAMP_TO_EDGE);
    ctx.texParameteri(ctx.TEXTURE_2D, ctx.TEXTURE_WRAP_T, ctx.CLAMP_TO_EDGE);
    ctx.texParameteri(ctx.TEXTURE_2D, ctx.TEXTURE_MIN_FILTER, ctx.LINEAR);
    ctx.texParameteri(ctx.TEXTURE_2D, ctx.TEXTURE_MAG_FILTER, ctx.LINEAR);

    // Draw the quad with the applied fragment shader
    ctx.drawArrays(ctx.TRIANGLES, 0, 6);
  }
}
