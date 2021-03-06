'use strict'

angular.module moduleComponent

.controller 'NavCtrl',
    ($scope, $state, Auth, Notify)->
        $scope.Auth = Auth

        performLogout = ()->
            Auth.logout()
            .then ->
                $state.go 'home'
                Notify 'ログアウトしました。', type: 'warn'

        $scope.items = [
            label: 'HOME'
            state: 'home'
        ,
            label: 'STUDY'
            state: 'study'
            visible: -> Auth.active()
        ,
            label: 'MAILLIST'
            state: 'ml'
            visible: -> Auth.active()
        ,
            label: 'ADMIN'
            state: 'admin'
            visible: -> Auth.admin()
        ,
            label: 'PROFILE'
            state: 'profile'
            visible: -> Auth.active()
        ,
            label: 'SIGNUP'
            state: 'signup'
            visible: -> not Auth.active()
        ,
            label: '<i class="fa fa-sign-out"></i>LOGOUT'
            event: ->
                if Auth.active()
                    performLogout()
            visible: -> Auth.active()
        ]

        $scope.isVisible = (item)->
            if item.visible? then item.visible() else true

        $scope.getHref = (item)->
            if item isnt '' then $state.href item.state else ''

        $scope.navEvent = (item)->
            if _.isFunction item.event
                item.event()

        $scope.navClass = (item)->
            'navbar__items__item--active': $state.includes item.state

        $scope.collapsed = true

        $scope.$on '$stateChangeStart', ->
            $scope.collapsed = true





