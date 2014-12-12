'use strict'

window.moduleConfig = 'hokuiConfig'

angular.module moduleConfig, [
    moduleCore
    'angular-google-analytics'
]

.config ($locationProvider)->
    $locationProvider.html5Mode true
    $locationProvider.hashPrefix '!'

.config ($urlRouterProvider)->
    $urlRouterProvider.rule ($injector, $location)->
        path = $location.url()
        replaced = false

        if path.indexOf('/?') > 0
            replaced = true
            path = path.replace('/?', '?')

        if path is not '/' or '/' is path[path.length - 1]
            replaced = true
            path = path.replace /\/$/, ''

        if replaced
            return path
        else
            return false

    $urlRouterProvider.otherwise ($injector)->
        $injector.get('$state').go '404', url: $injector.get('$location').absUrl()


.config (TokenProvider)->
    TokenProvider
    .setHeaderKey 'Access-Token'
    .setStorageKey 'token'
    .setTokenPrefix ''

.config (RestrictProvider)->
    RestrictProvider.setNext 'home'

.run ($rootScope, Restrict, $state, Auth, Notify)->

    hooking_first_change = true
    unregister = $rootScope.$on '$stateChangeStart', (ev, toState, toParams, fromState, fromParams)->
        go = ->
            hooking_first_change = false
            $state.transitionTo toState, toParams

        Auth.check().then go, go
        ev.preventDefault()
        unregister()

    $rootScope.$on '$stateChangeStart', (ev, toState, toParams, fromState, fromParams)->
        if hooking_first_change
            return
        result = Restrict toState
        first_visit = fromState.name is ''
        if not result.can
            ev.preventDefault()
            Notify result.error, type: 'warn', delay: if first_visit then 500 else 0
            $state.go result.next
