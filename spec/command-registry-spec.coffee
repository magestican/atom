CommandRegistry = require '../src/command-registry'

describe "CommandRegistry", ->
  [registry, parent, child, grandchild] = []

  beforeEach ->
    parent = document.createElement("div")
    child = document.createElement("div")
    grandchild = document.createElement("div")
    parent.classList.add('parent')
    child.classList.add('child')
    grandchild.classList.add('grandchild')
    child.appendChild(grandchild)
    parent.appendChild(child)
    document.querySelector('#jasmine-content').appendChild(parent)

    registry = new CommandRegistry(parent)

  describe "command dispatch", ->
    it "invokes callbacks with selectors matching the target", ->
      called = false
      registry.add '.grandchild', 'command', (event) ->
        expect(this).toBe grandchild
        expect(event.type).toBe 'command'
        expect(event.eventPhase).toBe Event.BUBBLING_PHASE
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe grandchild
        called = true

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(called).toBe true

    it "invokes callbacks with selectors matching ancestors of the target", ->
      calls = []

      registry.add '.child', 'command', (event) ->
        expect(this).toBe child
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe child
        calls.push('child')

      registry.add '.parent', 'command', (event) ->
        expect(this).toBe parent
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe parent
        calls.push('parent')

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['child', 'parent']

    it "orders multiple matching listeners for an element by selector specificity", ->
      child.classList.add('foo', 'bar')
      calls = []

      registry.add '.foo.bar', 'command', -> calls.push('.foo.bar')
      registry.add '.foo', 'command', -> calls.push('.foo')
      registry.add '.bar', 'command', -> calls.push('.bar') # specificity ties favor commands added later, like CSS

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['.foo.bar', '.bar', '.foo']

    it "stops bubbling through ancestors when .stopPropagation() is called on the event", ->
      calls = []

      registry.add '.parent', 'command', -> calls.push('parent')
      registry.add '.child', 'command', -> calls.push('child-2')
      registry.add '.child', 'command', (event) -> calls.push('child-1'); event.stopPropagation()

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['child-1', 'child-2']

    it "stops invoking callbacks when .stopImmediatePropagation() is called on the event", ->
      calls = []

      registry.add '.parent', 'command', -> calls.push('parent')
      registry.add '.child', 'command', -> calls.push('child-2')
      registry.add '.child', 'command', (event) -> calls.push('child-1'); event.stopImmediatePropagation()

      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['child-1']

    it "allows listeners to be removed via a disposable returned by ::add", ->
      calls = []

      disposable1 = registry.add '.parent', 'command', -> calls.push('parent')
      disposable2 = registry.add '.child', 'command', -> calls.push('child')

      disposable1.dispose()
      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual ['child']

      calls = []
      disposable2.dispose()
      grandchild.dispatchEvent(new CustomEvent('command', bubbles: true))
      expect(calls).toEqual []

    it "allows multiple commands to be registered under one selector when called with an object", ->
      calls = []

      disposable = registry.add '.child',
        'command-1': -> calls.push('command-1')
        'command-2': -> calls.push('command-2')

      grandchild.dispatchEvent(new CustomEvent('command-1', bubbles: true))
      grandchild.dispatchEvent(new CustomEvent('command-2', bubbles: true))

      expect(calls).toEqual ['command-1', 'command-2']

      calls = []
      disposable.dispose()
      grandchild.dispatchEvent(new CustomEvent('command-1', bubbles: true))
      grandchild.dispatchEvent(new CustomEvent('command-2', bubbles: true))
      expect(calls).toEqual []

  describe "::findCommands({target})", ->
    it "returns commands that can be invoked on the target or its ancestors", ->
      registry.add '.parent', 'namespace:command-1', ->
      registry.add '.child', 'namespace:command-2', ->
      registry.add '.grandchild', 'namespace:command-3', ->
      registry.add '.grandchild.no-match', 'namespace:command-4', ->

      expect(registry.findCommands(target: grandchild)[0..2]).toEqual [
        {name: 'namespace:command-3', displayName: 'Namespace: Command 3'}
        {name: 'namespace:command-2', displayName: 'Namespace: Command 2'}
        {name: 'namespace:command-1', displayName: 'Namespace: Command 1'}
      ]

  describe "::dispatch(target, commandName)", ->
    it "simulates invocation of the given command ", ->
      called = false
      registry.add '.grandchild', 'command', (event) ->
        expect(this).toBe grandchild
        expect(event.type).toBe 'command'
        expect(event.eventPhase).toBe Event.BUBBLING_PHASE
        expect(event.target).toBe grandchild
        expect(event.currentTarget).toBe grandchild
        called = true

      registry.dispatch(grandchild, 'command')
      expect(called).toBe true
