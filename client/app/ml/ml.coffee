'use strict'

angular.module appName
.config ($stateProvider) ->
    $stateProvider
    .state 'ml',
        url: '/ml'
        templateUrl: '/app/ml/ml.html'
        controller: 'MlCtrl'
        data:
            restrict:
                role: 'user'
                error: '/ml 以下へアクセスするにはログインしてください。'
                next: 'login'

.controller 'MlCtrl',
    ($scope) ->