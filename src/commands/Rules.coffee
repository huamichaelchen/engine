# CSS rules and conditions
GSS.Parser = require 'ccss-compiler'


class Rules
  
  # Comma combines found elements from multiple selectors without duplicates
  ',':
    # If all sub-selectors are native, make a single comma separated selector
    group: '$query'

    # Separate arguments with commas during serialization
    separator: ','

    serialized: true

    # Dont let undefined arguments stop execution
    eager: true

    # Return deduplicated collection of all found elements
    command: (operation, continuation, scope, meta) ->
      debugger
      contd = @queries.getScopePath(continuation) + operation.path
      return @queries.get(contd)

    # Recieve a single element found by one of sub-selectors
    # Duplicates are stored separately, they dont trigger callbacks
    capture: (result, operation, continuation, scope, meta) -> 
      
      contd = @queries.getScopePath(continuation) + operation.parent.path
      @queries.add(result, contd, operation.parent, scope, true)
      return contd + @identify(result) if meta == GSS.UP
      return true


    # Remove a single element that was found by sub-selector
    # Doesnt trigger callbacks if it was also found by other selector
    release: (result, operation, continuation, scope) ->
      contd = @queries.getScopePath(continuation) + operation.parent.path
      debugger
      @queries.remove(result, contd, operation.parent, scope, true)
      return true

  # Conditionals
  
  "rule":
    bound: 1

    # Set rule body scope to a found element
    evaluate: (operation, continuation, scope, meta, ascender, ascending) ->
      if operation.index == 2 && !ascender
        @expressions.evaluate operation, continuation, ascending, operation
        return false

    # Capture commands generated by css rule conditional branch
    capture: (result, parent, continuation, scope) ->
      if !result.nodeType && !@isCollection(result)
        @expressions.push result
        return true

  "if":
    # Resolve all values in first argument
    primitive: 1

    cleaning: true

    subscribe: (operation, continuation, scope) ->
      id = scope._gss_id
      watchers = @queries._watchers[id] ||= []
      if !watchers.length || @values.indexOf(watchers, operation, continuation, scope) == -1
        watchers.push operation, continuation, scope

    # Capture commands generated by a conditional branch
    capture: (result, operation, continuation, scope, meta) ->
      # Result of condition bubbled up,
      debugger
      if operation.index == 1

        @commands.if.branch.call(@, operation.parent[1], continuation, scope, meta, undefined, result)
        return true
      else
      # Capture commands bubbled up from branches
        if typeof result == 'object' && !result.nodeType && !@isCollection(result)
          @expressions.push result
          return true

    branch: (operation, continuation, scope, meta, ascender, ascending) ->
      @commands.if.subscribe.call(@, operation.parent, continuation, scope)
      operation.parent.uid ||= '@' + (@commands.uid = (@commands.uid ||= 0) + 1)
      condition = ascending && (typeof ascending != 'object' || ascending.length != 0)
      path = continuation + operation.parent.uid
      query = @queries[path]
      if query == undefined || (!!query != !!condition)
        @engine.console.group '%s \t\t\t\t%o\t\t\t%c%s', GSS.DOWN, operation.parent, 'font-weight: normal; color: #999', continuation
        unless query == undefined
          @queries.clean(path, continuation, operation.parent, scope)
        if condition
          @expressions.evaluate operation.parent[2], path, scope, meta
        else if operation.parent[3]
          @expressions.evaluate operation.parent[3], path, scope, meta
        @console.groupEnd(path)

        @queries[path] = condition ? null

  "text/gss-ast": (source) ->
    return JSON.parse(source)

  "text/gss": (source) ->
    return GSS.Parser.parse(source)?.commands

  "eval": 
    command: (operation, continuation, scope, meta, 
              node, type = 'text/gss', source) ->
      if node.nodeType
        if nodeType = node.getAttribute('type')
          type = nodeType
        source ||= node.textContent || node 
        if (nodeContinuation = node._continuation)?
          @queries.clean(nodeContinuation)
          continuation = nodeContinuation
        else if !operation
          continuation = @getContinuation(node.tagName.toLowerCase(), node)
        else
          continuation = node._continuation = @getContinuation(continuation || '', null,  GSS.DOWN)
        if node.getAttribute('scoped')?
          scope = node.parentNode

      rules = @['_' + type](source)
      rules = GSS.clone(rules)
      capture = @expressions.capture(type)
      @run rules, continuation, scope, GSS.DOWN
      @expressions.release() if capture
      return

  "load": 
    command: (operation, continuation, scope, meta, 
              node, type, method = 'GET') ->
      src = node.href || node.src || node
      type ||= node.type || 'text/gss'
      xhr = new XMLHttpRequest()
      xhr.onreadystatechange = =>
        if xhr.readyState == 4
          if xhr.status == 200
            capture = @expressions.capture(src)
            @_eval.command.call(@, operation, continuation, scope, meta,
                                   node, type, xhr.responseText)
            @expressions.release() if capture
      xhr.open(method.toUpperCase(), src)
      xhr.send()

for property, fn of Rules::
  fn.rule = true



module.exports = Rules