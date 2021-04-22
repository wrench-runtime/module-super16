import "wren_gles2" for GL, ClearFlag, BufferType, BufferHint, ShaderType, DataType, EnableCap, PrimitveType, ShaderParam, ProgramParam, TextureTarget, TextureParam, TextureWrapMode, TextureMagFilter, TextureMinFilter, TextureUnit, PixelType, PixelFormat, BlendFacSrc, BlendFacDst, FramebufferTarget, FramebufferAttachment, FramebufferStatus
import "image" for Image
import "buffer" for FloatArray, Uint16Array, Uint8Array, Buffer
import "wren_gles2_util" for Gles2Util, VertexAttribute, VertexIndices 
import "file" for File
import "wren_gles2_app" for Gles2Application
import "wren_sdl2" for SDL, SdlEventType, SdlKeyCode
import "named_tuple" for NamedTuple
import "super16/shaders" for FragmentFbo, FragmentTile, Fragment, VertexFbo, VertexTile, Vertex

var DEFAULT_WIN_WIDTH = 960
var DEFAULT_WIN_HEIGHT = 540
// var DEFAULT_WIN_WIDTH = 800
// var DEFAULT_WIN_HEIGHT = 480
// var DEFAULT_WIN_WIDTH = 480
// var DEFAULT_WIN_HEIGHT = 270
// var DEFAULT_WIN_WIDTH = 1920
// var DEFAULT_WIN_HEIGHT = 1080

var DEFAULT_FB_WIDTH = 480
var DEFAULT_FB_HEIGHT = 270
var DEFAULT_FB_TEX_WIDTH = 512
var DEFAULT_FB_TEX_HEIGHT = 512
var NUM_SPRITES = 1024
var NUM_GLYPHS = 1024
var NUM_LAYERS = 4
var LAYER_SIZE = 128
var VRAM_SIZE = 1024
var INTERPOLATE_FB = false

class Time {
}

class Input {
  static a { SDL.isKeyDown(SdlKeyCode.A) }
  static b { SDL.isKeyDown(SdlKeyCode.S) }
  static x { SDL.isKeyDown(SdlKeyCode.Y) }
  static y { SDL.isKeyDown(SdlKeyCode.X) }
  static start { SDL.isKeyDown(SdlKeyCode.Return) }
  static select { SDL.isKeyDown(SdlKeyCode.Space) }
  static left { SDL.isKeyDown(SdlKeyCode.Left) }
  static right { SDL.isKeyDown(SdlKeyCode.Right) }
  static up { SDL.isKeyDown(SdlKeyCode.Up) }
  static down { SDL.isKeyDown(SdlKeyCode.Down) }
}

class Sub {
  static current { __current }
  static current=(v) { __current=v }
  static parent { __current.parent }
  static root { __root }

  static wait(loops){
    if(loops == 0) return Fiber.yield()
    var c = 0
    while(c < loops){
      c = c+1
      Fiber.yield()
    }
  }
  static step() { Fiber.yield() }
  static waitFor(fn) { 
    while(!fn.call()) { 
      Fiber.yield() 
    } 
  }


  static init(){
    __currentId = 0
  }

  static update(){
    __root.update()
  }
  
  static run(fn) {
    var sub = Sub.new(fn, __current)
    if(sub.parent == null) __root = sub
    return sub
  }

  static runLoop(fn){
    return Sub.run {
      while(true){
        fn.call()
        Sub.step()
      }
    }
  }

  fiber { _fiber }
  parent { _parent }
  children { _children }
  isDone { _isDone }
  isPaused { _isPaused }
  id { _id }

  construct new(fn, parent){
    _fiber = fn is Fiber ? fn : Fiber.new(fn)
    _parent = parent
    __currentId = __currentId + 1
    _id = __currentId
    _children = []
    _isDone = false
    _isPaused = false
    _delete = []
    if(_parent) _parent.children.add(this)
  }

  addChild(sub){
    _children.add(sub)
  }

  togglePause(){
    _isPaused = !_isPaused
  }

  stop(){
    _isDone = true
  }

  update(){
    if(_isPaused){ 
      return 
    }
    if(_isDone){ 
      return
    }
    Sub.current = this
    _fiber.call()
    _isDone = _fiber.isDone
    for(i in 0..._children.count){
      _children[i].update()
      if(_children[i].isDone) _delete.insert(0,i)
    }
    for(i in _delete){
      _children.removeAt(i)
    }
    _delete.clear()
  }

  await(){
    while(!isDone){
      Fiber.yield()
    }
  }
}

class Super16 {
  static app { __app }
  static time { SDL.ticks }
  
  static init(){ Super16.init({}) }
  static init(options){
    __app = Gles2Application.new()
    __app.createWindow(DEFAULT_WIN_WIDTH, DEFAULT_WIN_HEIGHT, "Super16")
    __app.setVsync(true)
    Sub.init()
    Gfx.init(options)
  }

  static start(fn){
    Super16.init()
    Sub.run(fn)
    Super16.run()
  }

  static run(){
    __quit = false
    __frames = 0
    __frameTime = 0

    while(!__quit && !Sub.root.isDone){
      __time = SDL.ticks
      var ev = null
      while(ev = __app.poll()){
        if(ev.type == SdlEventType.Quit) __quit = true
      }
      Gfx.update()
      Gfx.draw()
      Sub.update()
      __app.swap()
      __app.checkErrors()
      
      // var passed = SDL.ticks - __time
      // if(passed < 33.33){
      //   SDL.delay(33.33-passed)
      // }
      __frames = __frames+1
      __frameTime = __frameTime + SDL.ticks - __time
      if(__frames == 100){
        System.print("Frametime %(__frameTime / 100)ms")
        __frames = 0
        __frameTime = 0
      }
    }
  }

}

var Vec2 = NamedTuple.create("Vec2", ["x","y"])

class Gfx {
  static flag1 { 0x1 }
  static flag2 { 0x2 }
  static flag3 { 0x4 }
  static flag4 { 0x8 }
  static flag5 { 0x10 }
  static flag6 { 0x20 }
  static flag7 { 0x40 }
  static flag8 { 0x80 }
  static flag9 { 0x100 }
  static layerShader { __layerShader } 
  static spriteShader { __spriteShader } 
  static spriteBuffer { __spriteBuffer }
  static layerBuffer { __layerBuffer }
  static sprites { __sprites }
  static glyphs { __glyphs }
  static fonts { __fonts }
  static fnt0 { __fnt0 }
  static fnt1 { __fnt1 }
  static fnt2 { __fnt2 }
  static fnt3 { __fnt3 }
  static layers { __layers }
  static bg0 { __bg0 }
  static bg1 { __bg1 }
  static bg2 { __bg2 }
  static bg3 { __bg3 }
  static width { Super16.app.width }
  static height { Super16.app.height }
  static tid(x,y) { (y<<8) | x }
  static xy(tid) {
    __vec2.x = tid & 0xFF
    __vec2.y = (tid>>8) & 0xFF
    return __vec2
  }
  static setFlag(flag, tid){ __flags[tid] = (__flags[tid] || 0) | flag }
  static hasFlag(flag, tid){ ((__flags[tid] || 0) & flag) == flag }
  static flags { __flags }

  static vram(x,y,img){
    GL.bindTexture(TextureTarget.TEXTURE_2D, __texture)
    GL.texSubImage2D(TextureTarget.TEXTURE_2D, 0, x, y, img.width, img.height, PixelFormat.RGBA, PixelType.UNSIGNED_BYTE, img.buffer)
  }

  // internal
  static init(options){
    __vec2 = Vec2.new(0,0)
    __width = options["width"] || DEFAULT_WIN_WIDTH
    __height = options["height"] || DEFAULT_WIN_HEIGHT

    __framebuffer = Framebuffer.new(DEFAULT_FB_WIDTH, DEFAULT_FB_HEIGHT)

    //var vertCode = File.read("./wren_modules/super16/vertex_tile.glsl")
    //var fragCode = File.read("./wren_modules/super16/fragment_tile.glsl")
    __layerShader = Shader.new(VertexTile, FragmentTile, ["size", "texSize", "tilesize", "texture", "map", "mapSize", "pixelation", "time","prio"])

    //fragCode = File.read("./wren_modules/super16/fragment.glsl")
    //vertCode = File.read("./wren_modules/super16/vertex.glsl")
    __spriteShader = Shader.new(Vertex, Fragment, ["size", "texSize", "texture","prio"])

    __spriteBuffer = SpriteBuffer.new(__spriteShader.program, NUM_SPRITES)
    __sprites = []
    for(i in 0...__spriteBuffer.count){
      __sprites.add(Sprite.new(i))
    }

    __fnt0 = Font.new(__spriteBuffer)
    __fnt1 = Font.new(__spriteBuffer)
    __fnt2 = Font.new(__spriteBuffer)
    __fnt3 = Font.new(__spriteBuffer)
    __fonts = [__fnt0,__fnt1,__fnt2,__fnt3]

    __layerBuffer = SpriteBuffer.new(__layerShader.program, NUM_LAYERS)
    __bg0 = BgLayer.new(LAYER_SIZE,LAYER_SIZE, 0, 2)
    __bg1 = BgLayer.new(LAYER_SIZE,LAYER_SIZE, 1, 4)
    __bg2 = BgLayer.new(LAYER_SIZE,LAYER_SIZE, 2, 6)
    __bg3 = BgLayer.new(LAYER_SIZE,LAYER_SIZE, 3, 8)
    __layers = [__bg0, __bg1, __bg2, __bg3]

    __texSize = [VRAM_SIZE, VRAM_SIZE]
    __texture = Gles2Util.createTexture(__texSize[0], __texSize[1])    
    __flags = {}
  }

  static update(){
    __bg0.update()
    __bg1.update()
    __bg2.update()
    __bg3.update()
    __layerBuffer.update()
    __spriteBuffer.update()
  }

  static draw(){
    GL.clearColor(0.5, 0.5, 0.5, 1.0)
    //GL.viewport(0,0,__width,__height)
    __framebuffer.use()
    GL.enable(EnableCap.BLEND)
    GL.blendFunc(BlendFacSrc.SRC_ALPHA, BlendFacDst.ONE_MINUS_SRC_ALPHA)
    GL.clear(ClearFlag.COLOR_BUFFER_BIT)
    
    GL.activeTexture(TextureUnit.TEXTURE0)
    GL.bindTexture(TextureTarget.TEXTURE_2D, __texture)

    __spriteShader.use()
    GL.uniform2f(__spriteShader.locations["size"], __framebuffer.width, __framebuffer.height)
    GL.uniform2f(__spriteShader.locations["texSize"], __texSize[0], __texSize[1])
    GL.uniform1i(__spriteShader.locations["texture"], 0)

    __layerShader.use()
    GL.uniform2f(__layerShader.locations["size"], __framebuffer.width, __framebuffer.height)
    GL.uniform2f(__layerShader.locations["texSize"], __texSize[0], __texSize[1])
    GL.uniform1i(__layerShader.locations["texture"], 0)
    GL.uniform1i(__layerShader.locations["map"], 1)
    GL.uniform2f(__layerShader.locations["mapSize"], LAYER_SIZE, LAYER_SIZE)
    GL.uniform1f(__layerShader.locations["time"], SDL.ticks / 1000)

    __layerShader.use()
    GL.uniform1f(Gfx.layerShader.locations["prio"], 2.0)
    __bg0.draw()
    GL.uniform1f(Gfx.layerShader.locations["prio"], 4.0)
    __bg1.draw()

    __spriteShader.use()
    GL.uniform1f(Gfx.spriteShader.locations["prio"], 1)
    __spriteBuffer.draw()

    __layerShader.use()
    GL.uniform1f(Gfx.layerShader.locations["prio"], 3.0)
    __bg0.draw()
    GL.uniform1f(Gfx.layerShader.locations["prio"], 5.0)
    __bg1.draw()
    
    __spriteShader.use()
    GL.uniform1f(Gfx.spriteShader.locations["prio"], 2)
    __spriteBuffer.draw()
    
    __layerShader.use()
    GL.uniform1f(Gfx.layerShader.locations["prio"], 6.0)
    __bg2.draw()
    GL.uniform1f(Gfx.layerShader.locations["prio"], 8.0)
    __bg3.draw()
    
    __spriteShader.use()
    GL.uniform1f(Gfx.spriteShader.locations["prio"], 3)
    __spriteBuffer.draw()
    
    __layerShader.use()
    GL.uniform1f(Gfx.layerShader.locations["prio"], 7.0)
    __bg2.draw()
    GL.uniform1f(Gfx.layerShader.locations["prio"], 8.0)
    __bg3.draw()

    __spriteShader.use()
    GL.uniform1f(Gfx.spriteShader.locations["prio"], 4)
    __spriteBuffer.draw()
    GL.uniform1f(Gfx.spriteShader.locations["prio"], 1)

    __framebuffer.draw(DEFAULT_WIN_WIDTH, DEFAULT_WIN_HEIGHT)
  }
}

var Rect = NamedTuple.create("Rect", ["x","y","w","h"])
var RectEmpty = Rect.new(0,0,0,0)

class Font {
  
  space { _space }
  space=(v) { _space = v }
  
  construct new(buffer){
    _glyphs = {}
    _buffer = buffer
    _space = 0
  }

  glyph(codePoint, x, y, w, h){
    _glyphs[codePoint] = Rect.new(x,y,w,h)
  }

  text(x,y,start,text, prio){
    for(cp in text){
      if(cp == " ") {
        x = x + _space
        continue
      }
      var rect = sprite(cp, start, x, y, prio)
      start = start+1
      x = x+rect.w
    }
    return start
  }

  text(x,y,start,txt) { text(x,y,start,txt,1) }

  clear(){
    _glyphs = {}
  }

  sprite(codePoint, id, x, y, prio){
    var rect = _glyphs[codePoint] || RectEmpty
    _buffer.setSource(id, rect.x, rect.y, rect.w, rect.h)
    _buffer.setShape(id, 0, 0, rect.w, rect.h, 0, rect.h)
    _buffer.setTranslation(id, x, y)
    _buffer.setPrio(id, prio)
    return rect
  }
}

class Framebuffer {

  width { _w }
  height { _h }

  construct new(w, h){
    _w = w
    _h = h
    _tex = Gles2Util.createTexture(DEFAULT_FB_TEX_WIDTH, DEFAULT_FB_TEX_HEIGHT, { "interpolate": INTERPOLATE_FB })
    _fbo = GL.createFramebuffer()
    //_program = Shader.new(File.read("./wren_modules/super16/vertex_fbo.glsl"), File.read("./wren_modules/super16/fragment_fbo.glsl"), [])
    _program = Shader.new(VertexFbo, FragmentFbo, [])
    _program.use()
    _position = VertexAttribute.fromList(GL.getAttribLocation(_program.program, "position"), 2, [-1,1, -1,-1, 1,-1, 1,1])
    _uv = VertexAttribute.fromList(GL.getAttribLocation(_program.program, "uv"), 2, [0,_h/DEFAULT_FB_TEX_HEIGHT, 0,0, _w/DEFAULT_FB_TEX_WIDTH,0, _w/DEFAULT_FB_TEX_WIDTH,_h/DEFAULT_FB_TEX_HEIGHT])
    _indices = VertexIndices.fromList([3,2,1,3,1,0])
    GL.bindFramebuffer(FramebufferTarget.FRAMEBUFFER, _fbo)
    GL.framebufferTexture2D(FramebufferTarget.FRAMEBUFFER, FramebufferAttachment.COLOR_ATTACHMENT0, TextureTarget.TEXTURE_2D, _tex, 0)
    var status = GL.checkFramebufferStatus(FramebufferTarget.FRAMEBUFFER)
    if(status != FramebufferStatus.FRAMEBUFFER_COMPLETE) Fiber.abort("Framebuffer incomplete %(status)")
    GL.bindFramebuffer(FramebufferTarget.FRAMEBUFFER, null)
  }

  use(){
    GL.bindFramebuffer(FramebufferTarget.FRAMEBUFFER, _fbo)
    GL.viewport(0, 0, _w, _h)
    GL.clear(ClearFlag.COLOR_BUFFER_BIT)
  }

  draw(w, h){
    GL.bindFramebuffer(FramebufferTarget.FRAMEBUFFER, null)
    GL.viewport(0, 0, w, h)
    _program.use()
    _position.enable()
    _uv.enable()
    GL.activeTexture(TextureUnit.TEXTURE0)
    GL.bindTexture(TextureTarget.TEXTURE_2D, _tex)
    _indices.draw()
  }
}

class BgLayer {
  
  enabled { _enabled }
  enabled=(v) { _enabled = v }
  mosaic=(v) { _pixel = 2.pow(v) }
  
  construct new(w,h,id,prio){
    _w = w
    _h = h
    _buffer = Buffer.new(w*h*4)
    _uint16 = Uint16Array.fromBuffer(_buffer)
    _uint8 = Uint8Array.fromBuffer(_buffer)
    _texture = Gles2Util.createTexture(w,h)
    _id = id
    _enabled = true
    _prio = prio
    _tw = 16
    _th = 16
    _pixel = 1
    Gfx.layerBuffer.setShape(id, 0, 0, 2, 2, 1, 1)
    Gfx.layerBuffer.setSource(id, 0, 0, 1,1)
    Gfx.layerBuffer.setPrio(id, prio)
  }

  tileSize(w,h){
    _tw = w
    _th = h
  }

  pos(x,y){
    Gfx.layerBuffer.setTranslation(_id, x, y)
  }

  rot(r){
    Gfx.layerBuffer.setRotation(_id, r)
  }

  int(i){
    Gfx.layerBuffer.setIntensity(_id,i)
  }

  color(r,g,b,a){
    Gfx.layerBuffer.setColor(_id,r,g,b,a)
  }

  opacity(o){
    Gfx.layerBuffer.setOpacity(_id,o)
  }
  
  // todo bounds checking
  tile(x,y, tid){
    if(tid == null) Fiber.abort("TID is null")
    var offset = (y*_w+x)*2
    _uint16[offset] = tid
  }

  // todo bounds checking
  [x,y] { _uint16[(y*_w+x)*2] }

  // todo bounds checking
  tileFill(x,y,w,h,tid){
    for(cy in y...(y+h)){
      for(cx in x...(x+w)){
        tile(cx,cy,tid)
      }
    }
  }

  // todo bounds checking
  tilePlot(x,y,w,h,list){
    for(cy in y...(y+h)){
      for(cx in x...(x+w)){
        var tid = list[cy*w+cx]
        if(tid != 0) tile(cx,cy,tid)
      }
    }
  }

  // todo bounds checking
  hasFlag(x,y,flag){ Gfx.hasFlag(flag, this[x,y]) }
  
  prio(x,y, isPrio){
    _uint8[(y*_w+x)*4+2] = isPrio ? 1 : 0
  }
  
  update(){
    GL.bindTexture(TextureTarget.TEXTURE_2D, _texture)
    GL.texSubImage2D(TextureTarget.TEXTURE_2D, 0, 0, 0, _w, _h, PixelFormat.RGBA, PixelType.UNSIGNED_BYTE, _buffer)
  }

  draw(){
    if(_enabled){
      GL.activeTexture(TextureUnit.TEXTURE1)
      GL.bindTexture(TextureTarget.TEXTURE_2D, _texture)
      GL.uniform1f(Gfx.layerShader.locations["pixelation"], _pixel)
      GL.uniform2f(Gfx.layerShader.locations["tilesize"], _tw, _th)
      Gfx.layerBuffer.draw()
    }
  }
}

class Shader {
  locations {_locations }
  program { _program }

  construct new(vertex, fragment, uniforms){
    _program = Gles2Util.compileShader(vertex, fragment)
    _locations = {}
    for(name in uniforms){
      _locations[name] = GL.getUniformLocation(_program, name)
    }
  }

  use(){
    GL.useProgram(_program)
  }
}

class Sprite {
  prio=(v) { Gfx.spriteBuffer.setPrio(_id, v) }
  rot=(v) { Gfx.spriteBuffer.setRotation(_id,v) }
  id { _id }

  construct new(id){
    _id = id
  }

  set(w,h,sx,sy) { set(w,h,sx,sy,w/2, h/2) }
  set(w,h,sx,sy,ox,oy){
    Gfx.spriteBuffer.setShape(_id, 0, 0, w, h, ox, oy)
    Gfx.spriteBuffer.setSource(_id, sx, sy, w, h)
  }
  setTid(tid, size, ox, oy){
    var v2 = Gfx.xy(tid)
    set(size, size, v2.x*size, v2.y*size, ox, oy)
  }
  setTid(tid, size){
    setTid(tid, size, size/2, size/2)
  }

  pos(x,y){
    Gfx.spriteBuffer.setTranslation(_id, x,y)
  }

  mov(x,y){
    Gfx.spriteBuffer.offsetTranslation(_id, x,y)
  }

  rot(r){
    Gfx.spriteBuffer.offsetRotation(_id,r)
  }

  scale(x,y){
    Gfx.spriteBuffer.setScale(_id, x, y)
  }

  int(i){
    Gfx.spriteBuffer.setIntensity(_id, i)
  }

  color(r,g,b){
    Gfx.spriteBuffer.setColor(_id, r,g,b)
  }

  opacity(o){
    Gfx.spriteBuffer.setOpacity(_id, o)
  }
}

foreign class SpriteBuffer {
  foreign count

  construct new(shader, count){}

  foreign setShape(i,x, y, w, h, ox, oy)
  foreign setSource(i, x, y, w, h)
  foreign setTranslation(i, x, y)
  foreign offsetTranslation(i, x, y)
  foreign setRotation(i, r)
  foreign offsetRotation(i, r)
  foreign setScale(i, x, y)
  foreign offsetScale(i, x, y)
  foreign setPrio(i, p)
  foreign setColor(i,r,g,b)
  foreign setOpacity(i,o)
  foreign setIntensity(i,int)
  foreign getPrio(i)
  foreign update()
  foreign draw()
}