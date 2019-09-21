loadError = (url) ->
  """
    Unable to load NetLogo model from #{url}, please ensure:
    <ul>
      <li>That you can download the resource <a target="_blank" href="#{url}">at this link</a></li>
      <li>That the server containing the resource has
        <a target="_blank" href="https://en.wikipedia.org/wiki/Cross-origin_resource_sharing">
          Cross-Origin Resource Sharing
        </a>
        configured appropriately</li>
    </ul>
    If you have followed the above steps and are still seeing this error,
    please send an email to our <a href="mailto:bugs@ccl.northwestern.edu">"bugs" mailing list</a>
    with the following information:
    <ul>
      <li>The full URL of this page (copy and paste from address bar)</li>
      <li>Your operating system and browser version</li>
    </ul>
  """

toNetLogoWebMarkdown = (md) ->
  md.replace(
    new RegExp('<!---*\\s*((?:[^-]|-+[^->])*)\\s*-*-->', 'g')
    (match, commentText) ->
      "[nlw-comment]: <> (#{commentText.trim()})")

toNetLogoMarkdown = (md) ->
  md.replace(
    new RegExp('\\[nlw-comment\\]: <> \\(([^\\)]*)\\)', 'g'),
    (match, commentText) ->
      "<!-- #{commentText} -->")

# handleAjaxLoad : String, (String) => (), (XMLHttpRequest) => () => Unit
handleAjaxLoad = (url, onSuccess, onFailure) =>
  req = new XMLHttpRequest()
  req.open('GET', url)
  req.onreadystatechange = () ->
    if req.readyState is req.DONE
      if (req.status is 0 or req.status >= 400)
        onFailure(req)
      else
        onSuccess(req.responseText)
  req.send("")

# newSession: String|DomElement, Array[Rewriter], ModelResult,
#   Boolean, String => SessionLite
newSession = (container, rewriters, modelResult,
  readOnly = false, filename = "export", lastCompileFailed, onError = undefined) ->
  { code, info, model: { result }, widgets: wiggies } = modelResult
  widgets = globalEval(wiggies)
  info    = toNetLogoWebMarkdown(info)
  new SessionLite(container, rewriters, widgets, code, info, readOnly, filename, result, lastCompileFailed, onError)

# We separate on both / and \ because we get URLs and Windows-esque filepaths
normalizedFileName = (path) ->
  pathComponents = path.split(/\/|\\/)
  decodeURI(pathComponents[pathComponents.length - 1])

loadData = (container, pathOrURL, name, loader, onError) ->
  {
    container,
    loader,
    onError,
    modelPath: pathOrURL,
    name
  }

openSession = (load, rewriters) -> (model, lastCompileFailed) ->
  name    = load.name ? normalizedFileName(load.modelPath)
  session = newSession(load.container, rewriters, model, false, name, lastCompileFailed, load.onError)
  load.loader.finish()
  session

# process: function which takes a loader as an argument, producing a function that can be run
loading = (process) ->
  document.querySelector("#loading-overlay").style.display = ""
  loader = {
    finish: () -> document.querySelector("#loading-overlay").style.display = "none"
  }
  setTimeout(process(loader), 20)

defaultDisplayError = (container) ->
  (errors) -> container.innerHTML = "<div style='padding: 5px 10px;'>#{errors}</div>"

reportCompilerError = (load) -> (res) ->
  errors = res.model.result.map(
    (err) ->
      contains = (s, x) -> s.indexOf(x) > -1
      message = err.message
      if contains(message, "Couldn't find corresponding reader") or contains(message, "Models must have 12 sections")
        "#{message} (see <a href='https://netlogoweb.org/docs/faq#model-format-error'>here</a> for more information)"
      else
        message
  ).join('<br/>')
  load.onError(errors)
  load.loader.finish()

reportAjaxError = (load) -> (req) ->
  load.onError(loadError(load.modelPath))
  load.loader.finish()

# process: optional argument that allows the loading process to be async to
# give the animation time to come up.
startLoading = (process) ->
  document.querySelector("#loading-overlay").style.display = ""
  # This gives the loading animation time to come up. BCH 7/25/2015
  if (process?) then setTimeout(process, 20)

finishLoading = ->
  document.querySelector("#loading-overlay").style.display = "none"

fromNlogo = (nlogo, container, path, callback, onError = defaultDisplayError(container), rewriters = []) ->
  loading((loader) ->
    segments  = path.split(/\/|\\/)
    name      = segments[segments.length - 1]
    load      = loadData(container, path, name, loader, onError)

    handleCompilation(nlogo, callback, load, rewriters)
  )

fromURL = (url, modelName, container, callback, onError = defaultDisplayError(container), rewriters = []) ->
  loading((loader) ->
    load    = loadData(container, url, modelName, loader, onError)
    compile = (nlogo) ->
      handleCompilation(nlogo, callback, load, rewriters)

    handleAjaxLoad(url, compile, reportAjaxError(load))
  )

handleCompilation = (nlogo, callback, load, rewriters) ->
  onSuccess = (input, lastCompileFailed) -> callback(openSession(load, rewriters)(input, lastCompileFailed))
  onFailure = reportCompilerError(load)

  compiler       = (new BrowserCompiler())
  rewriter       = (newCode, rw) -> rw.rewriteNlogo(newCode)
  rewrittenNlogo = rewriters.reduce(rewriter, nlogo)
  result         = compiler.fromNlogo(rewrittenNlogo, [])

  if result.model.success
    result.code = if nlogo is rewrittenNlogo then result.code else nlogoToSections(nlogo)[0].slice(0, -1)
    onSuccess(result, false)
  else
    success = fromNlogoWithoutCode(nlogo, compiler, onSuccess)
    onFailure(result, success)
    return

nlogoToSections = (nlogo) ->
  nlogo.split(/^\@#\$#\@#\$#\@$/gm)

sectionsToNlogo = (sections) ->
  sections.join("@#$#@#$#@")

# If we have a compiler failure, maybe just the code section has errors.
# We do a second chance compile to see if it'll work without code so we
# can get some widgets/plots on the screen and let the user fix those
# errors up.  -JMB August 2017

# (String, BrowserCompiler, (Model) => Session?) => Boolean
fromNlogoWithoutCode = (nlogo, compiler, onSuccess) ->
  sections = nlogoToSections(nlogo)
  if sections.length isnt 12
    false
  else
    oldCode     = sections[0]
    sections[0] = ""
    newNlogo    = sectionsToNlogo(sections)
    result      = compiler.fromNlogo(newNlogo, [])
    if not result.model.success
      false
    else
      # It mutates state, but it's an easy way to get the code re-added
      # so it can be edited/fixed.
      result.code = oldCode
      onSuccess(result, true)
      result.model.success

Tortoise = {
  startLoading,
  finishLoading,
  fromNlogo,
  fromURL,
  toNetLogoMarkdown,
  toNetLogoWebMarkdown,
  nlogoToSections,
  sectionsToNlogo
}

if window?
  window.Tortoise  = Tortoise
else
  exports.Tortoise = Tortoise

# See http://perfectionkills.com/global-eval-what-are-the-options/ for what
# this is doing. This is a holdover till we get the model attaching to an
# object instead of global namespace. - BCH 11/3/2014
globalEval = eval
