; extends

; Inject XML into consecutive /// doc comments. Skip the first three
; characters (the `///` prefix) and combine adjacent matches so a
; multi-line <summary>…</summary> parses as one XML document.
((comment) @injection.content
  (#match? @injection.content "^///")
  (#offset! @injection.content 0 3 0 0)
  (#set! injection.language "xml")
  (#set! injection.combined))
