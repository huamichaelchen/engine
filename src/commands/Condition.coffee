Query = require('../Query')

class Condition extends Query
  type: 'Condition'

  Sequence: undefined

  signature: [
    if: ['Query', 'Selector', 'Variable', 'Constraint', 'Default'],
    then: ['Any'],
    [
      else: ['Any']
    ]
  ]

  List: {
    2: true
    3: true
  }

  
  cleaning: true

  conditional: 1
  boundaries: true
  domains:
    1: 'output'

  constructor: (operation, engine) ->
    @path = @key = @serialize(operation, engine)

    if @linked
      if parent = operation.parent
        previous = parent[parent.indexOf(operation) - 1]
        if command = previous.command
          if command.type == 'Condition'
            command.next = operation
            @previous = command

  # Condition was not evaluated yet
  descend: (engine, operation, continuation, scope) ->
    continuation = @delimit(continuation, @DESCEND)

    if @conditional
      path = continuation + @key
      unless engine.queries.hasOwnProperty(path)
        engine.queries[path] = 0
        evaluate = true
      
      @after([], engine.queries[path], engine, operation, continuation, scope)
      if evaluate
        branch = operation[@conditional]
        branch.command.solve(engine, branch, continuation, scope)


    return false

  execute: (value) ->
    return value

  serialize: (operation, engine) ->
    return '@' + @toExpression(operation[1])

  getOldValue: (engine, continuation) ->
    old = engine.updating.snapshots?[continuation] ? 0
    return old > 0 || (old == 0 && 1 / old != -Infinity)

  ascend: (engine, operation, continuation, scope, result) ->
    if conditions = (engine.updating.branches ||= [])
      if engine.indexOfTriplet(conditions, operation, continuation, scope) == -1
        length = continuation.length
        for condition, index in conditions by 3
          contd = conditions[index + 1]
          if contd.length >= length
            break
          # Top branch is switching
          else if continuation.substring(0, contd.length) == contd
            return

        conditions.splice(index || 0, 0, operation, continuation, scope)

  rebranch: (engine, operation, continuation, scope) ->
    increment = if @getOldValue(engine, continuation) then -1 else 1
    engine.queries[continuation] = (engine.queries[continuation] || 0) + increment

    inverted = operation[0] == 'unless'
    index = @conditional + 1 + ((increment == -1) ^ inverted)

    if branch = operation[index]
      engine.console.start(index == 2 && 'if' || 'else', operation[index], continuation)
      result = engine.input.Command(branch).solve(engine.input, branch, @delimit(continuation, @DESCEND), scope)
      engine.console.end(result)

  unbranch: (engine, operation, continuation, scope) ->
    if old = engine.updating.snapshots?[continuation]
      increment = if @getOldValue(engine, continuation) then -1 else 1
      if (engine.queries[continuation] += increment) == 0
        @clean(engine, continuation, continuation, operation, scope)
        return true

  # Capture commands generated by evaluation of arguments
  yield: (result, engine, operation, continuation, scope) ->
    # Condition result bubbled up, pick a branch
    unless operation.parent.indexOf(operation) > 1
      if operation[0].key?
        continuation = operation[0].key
        if scoped = operation[0].scope
          scope = engine.identity[scoped]

      if @bound
        continuation = @getPrefixPath(engine, continuation)

      path = @delimit(continuation, @DESCEND) + @key


      if result?.push && result.valueOf != Array::valueOf
        result = result.valueOf() || false
  
      value = engine.queries[path]

      if result && !value
        value = -0

      (engine.updating.snapshots ||= {})[path] = value

      if old = engine.updating.snapshots?[path]
        if @getOldValue(engine, path) == !!result
          return true

      @notify(engine, path, scope, result)


      return true

# Detect condition that only observes variables outside of current scope
Condition.Global = Condition.extend

  condition: (engine, operation, command) ->
    if command
      operation = operation[1]
    if operation[0] == 'get' || operation[1] == 'virtual'
      if operation.length == 2
        return false
    else if operation[0] == '&'
      return false
    for argument in operation
      if argument && argument.push && @condition(engine, argument) == false
        return false
    return true

  global: true

# Detect condition that observes selectors
Condition.Selector = Condition.extend

  condition: (engine, operation, command) ->
    if command
      operation = operation[1]
    if operation.command.type == 'Selector' &&
        (operation.length > 1 ||
          (operation.parent.command.type == 'Selector' &&
          operation.parent.command.type == 'Iterator'))
      return true
    for argument in operation
      if argument && argument.push && @condition(engine, argument)
        return true
    return false

  bound: true

Condition::advices = [Condition.Selector, Condition.Global]

Condition.define 'if', {}
Condition.define 'unless', {
  inverted: true
}
Condition.define 'else', {
  signature: [
    then: ['Any']
  ]

  linked: true

  conditional: null
  domains: null
}
Condition.define 'elseif', {
  linked: true
}
Condition.define 'elsif', {
}

module.exports = Condition
