type
  Content* = tuple[idx: int, content: string]
  Paragraph* = string
  AITranslatorOption* = tuple[
    apiKey: string,
    model: string,
    baseUrl: string
  ]