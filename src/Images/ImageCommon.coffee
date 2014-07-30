ImageCommon =
  decodeError: (file, post) ->
    return false unless file.error?.code is MediaError.MEDIA_ERR_DECODE
    unless message = $ '.warning', post.file.thumb.parentNode
      message = $.el 'div', className:   'warning'
      $.after post.file.thumb, message
    message.textContent = 'Error: Corrupt or unplayable video'
    return true

  error: (file, post, delay, cb) ->
    return cb null unless file.src.split('/')[2] is 'i.4cdn.org'
    return ImageCommon.retry post, cb if post.isDead or post.file.isDead

    timeoutID = setTimeout ImageCommon.retry, delay, post, cb if delay?
    return if post.isDead or post.file.isDead
    kill = (fileOnly) ->
      clearTimeout timeoutID
      post.kill fileOnly
      ImageCommon.retry post, cb

    <% if (type === 'crx') { %>
    $.ajax post.file.URL,
      onloadend: ->
        return if @status isnt 404
        kill true
    ,
      type: 'head'
    <% } else { %>
    # XXX CORS for i.4cdn.org WHEN?
    $.ajax "//a.4cdn.org/#{post.board}/thread/#{post.thread}.json", onload: ->
      return kill() if @status is 404
      return if @status isnt 200
      for postObj in @response.posts
        break if postObj.no is post.ID
      if postObj.no isnt post.ID
        kill()
      else if postObj.filedeleted
        kill true
    <% } %>

  retry: (post, cb) ->
    unless post.isDead or post.file.isDead
      return cb post.file.URL + '?' + Date.now()
    src = post.file.URL.split '/'
    URL = Redirect.to 'file',
      boardID:  post.board.ID
      filename: src[src.length - 1]
    if URL and (/^https:\/\//.test(URL) or location.protocol is 'http:')
      return cb URL
    cb null # report nothing to retry

  # Add controls, but not until the mouse is moved over the video.
  addControls: (video) ->
    handler = ->
      $.off video, 'mouseover', handler
      # Hacky workaround for Firefox forever-loading bug for very short videos
      t = new Date().getTime()
      $.asap (-> chrome? or (video.readyState >= 3 and video.currentTime <= Math.max 0.1, (video.duration - 0.5)) or new Date().getTime() >= t + 1000), ->
        video.controls = true
    $.on video, 'mouseover', handler