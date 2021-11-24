import Vue from 'vue'
import BetterGesture from './better-gesture.js'

let CACHE = []

let getElemCacheIndex = function(elem) {
  for (let i = 0, len = CACHE.length; i < len; i++) {
    if (CACHE[i].elem === elem) {
      return i
    }
  }
  return null
}

let doOnOrOff = function(cacheObj, options) {
  let eventName = options.eventName
  let elem = options.elem
  let func = options.func
  let modifiers = options.modifiers
  let oldFunc = options.oldFunc
  if (cacheObj && cacheObj.gesture) {
    if (cacheObj.gesture.off && oldFunc) {
      cacheObj.gesture.off(eventName, oldFunc)
    }
    if (cacheObj.gesture.on && func) {
      cacheObj.gesture.on(eventName, func)
    }
  } else {
    options = {
      modifiers,
      eventName
    }
    options[eventName] = func
    CACHE.push({
      elem: elem,
      gesture: new BetterGesture(elem, options)
    })
  }
}

let EV_Directive = ['tap', 'longtap', 'swipe', 'swipeleft', 'swiperight', 'swipeup', 'swipedown', 'pressmove', 'rotate', 'pinch', 'start', 'end']

EV_Directive.forEach(eventName => {
  Vue.use({
    BetterGesture,
		install() {
      // 使用vue3可兼容的方式
			Vue.directive('GT-' + eventName, {
				bind: function(elem, binding) {
					let func = binding.value
					let oldFunc = binding.oldValue
					let cacheObj = CACHE[getElemCacheIndex(elem)]

					doOnOrOff(cacheObj, {
						elem: elem,
						func: func,
						oldFunc: oldFunc,
						eventName,
            modifiers: binding.modifiers
					})
				},
				unbind: function(elem) {
					let index = getElemCacheIndex(elem)

					if (!isNaN(index)) {
						let delArr = CACHE.splice(index, 1)
						if (delArr.length && delArr[0] && delArr[0].gesture.destroy) {
							delArr[0].gesture.destroy()
						}
					}
				}
			})
		}
  })
})
