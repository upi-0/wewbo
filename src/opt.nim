import
  tui/questionable/[option, base]

export
  Questionable, OptionJson, OptionValuedQuestionable

export  
  ask, put, putEnum, putRange
  
when isMainModule:

  discard """
    var opt: OptionJson = newJObject()

    opt.put("default", "api")
    opt.putEnum(["ffmpeg", "mpv", "vlc"], "player")
    opt.putRange(1, 24, "fps")
    
    opt.ask()

    echo opt["api"].s
    echo opt["player"].s
    echo opt["fps"].n
  """

  discard """
    type Rijal = ref object of RootObj
      nama: string
      umur: int
      opt: OptionJson = newJObject()

    proc newRijal() : Rijal =
      result = Rijal()
      result.opt.put("-", "nama")
      result.opt.putEnum(["On", "Off"], "status")
      result.opt.putRange(0, 100, "hitam", 50)

    let rijal = newRijal()
    rijal.opt.ask()
  """
