import ./terminal/paramarg

var optionsParser = loadArguments()

optionsParser.add(
  flag = "-n",
  name = "name",
  val = tString,
  default = "kura"
)

optionsParser.add(
  flag = "-p",
  name = "player",
  val = tString,
)

optionsParser.parse()

export
  optionsParser,
  paramarg
