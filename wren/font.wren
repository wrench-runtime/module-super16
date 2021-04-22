import "super16" for Gfx
import "json" for Json
import "file" for File
import "image" for Image

class FontLoader {
  static loadJson(jsonFile, font, vramx, vramy){
    var json = Json.parse(File.read(jsonFile))
    // jsonFile = jsonFile.replace("\\","/")
    // var frags = jsonFile.split("/")
    // frags.removeAt(frags.count-1)
    // var imageFile = frags.join("/") + "/%(json["image"])"
    // var img = Image.fromFile(imageFile)
    // Gfx.vram(vramx, vramy, img)
    var fnt = FontLoader.new(font, vramx, vramy, json["line-height"])
    font.space = json["space"] || 0
    for(i in 0...json["glyphs"].count){
      var glyphs = json["glyphs"][i]
      var widths = json["widths"][i]
      for(j in 0...glyphs.count) {
        var cp = glyphs[j]
        var width = widths[j]
        fnt.addGlyph(cp, width)
      }
      fnt.newLine()
    }
  }

  construct new(fnt, x, y, lineHeight){
    _startX = x
    _x = x
    _y = y
    _font = fnt
    _lineHeight = lineHeight
    
    fnt.clear()
  }

  addGlyph(codePoint,width){
    _font.glyph(codePoint, _x, _y, width, _lineHeight)
    _x = _x + width
  }

  newLine(){
    _y = _y + _lineHeight
    _x = _startX
  }
}