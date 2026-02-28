import 
  pkg/htmlparser,
  q,
  xmltree,
  httpclient,
  json,
  zippy

proc to_readable*(response: Response) : string =
  result = response.body
  try:
    result = result.uncompress()
  except ZippyError:
    discard

proc to_json*(response: Response) : JsonNode =
  response.to_readable().parseJson()

proc to_selector*(content: string) : XmlNode =
  var
    content = parseHtml(content)
    html = q(content)
    
  return html.select("")[0]

proc to_selector*(response: Response) : XmlNode =    
  return response.to_readable().to_selector()

export
  XmlNode,
  JsonNode,
  attr,
  attrs,
  select