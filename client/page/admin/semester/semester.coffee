'use strict'

angular.module modulePage
.config ($stateProvider) ->
    $stateProvider

    .state 'admin.semester',
        url: '/semester?class_year&subject',
        views:
            'main@admin':
                templateUrl: '/page/admin/semester/semester.html'
                controller: 'AdminSemesterCtrl'
                resolve:
                    semesters: (Semester)->
                        Semester.query().$promise
                    classYears: (ClassYear)->
                        ClassYear.query().$promise
                    subjects: (Subject)->
                        Subject.query().$promise


            'main@admin.semester':
                templateUrl: '/page/admin/semester/list.html'
                controller: 'AdminSemesterListCtrl'

    .state 'admin.semester.new',
        url: '/new',
        views:
            'main@admin.semester':
                templateUrl: '/page/admin/semester/edit.html'
                controller: 'AdminSemesterEditCtrl'

    .state 'admin.semester.detail',
        url: '/{id:int}',
        views:
            'main@admin.semester':
                templateUrl: '/page/admin/semester/detail.html'
                controller: 'AdminSemesterDetailCtrl'

    .state 'admin.semester.detail.edit',
        url: '/edit',
        views:
            'edit@admin.semester.detail':
                templateUrl: '/page/admin/semester/edit.html'
                controller: 'AdminSemesterEditCtrl'


.controller 'AdminSemesterCtrl',
    ($scope, ResourceStore, semesters, classYears, subjects) ->
        $scope.semesters = new ResourceStore semesters
        $scope.classYears = new ResourceStore classYears
        $scope.subjects = new ResourceStore subjects

        map_ab =
            a: '前期'
            b: '後期'
        $scope.identifierMap = {}
        for grade in [2..6]
            for label in ['a','b']
                $scope.identifierMap["#{grade}#{label}"] = "#{grade}年#{map_ab[label]}"

.controller 'AdminSemesterListCtrl',
    ($scope, $state, $stateParams, ResourceFilter) ->

        semesterFilter = new ResourceFilter()

        $scope.classYearFilter = new ResourceFilter
            parent: semesterFilter
            alternative: true
        _.forEach $scope.classYears.original, (cy)->
            $scope.classYearFilter.append new ResourceFilter
                slug: cy.year
                label: "#{cy.year}期"
                filter: (semester)->
                    semester.class_year_id is cy.id

        $scope.yearFilter = new ResourceFilter
            parent: semesterFilter
            alternative: true
        _.forEach [2..6], (year)->
            strYear = ''+year
            $scope.yearFilter.append new ResourceFilter
                label: "#{year}年"
                filter: (semester)->
                    semester.identifier[0] is strYear

        $scope.abFilter = new ResourceFilter
            parent: semesterFilter
            alternative: true
        .append new ResourceFilter
            label: '前期'
            filter: (semester)->
                semester.identifier[1] is 'a'
        .append new ResourceFilter
            label: '後期'
            filter: (semester)->
                semester.identifier[1] is 'b'

        subjectMap = {}
        for subject in $scope.subjects.original
            subjectMap[subject.id] = subject

        $scope.subjectFilter = new ResourceFilter
            parent: semesterFilter
            value: ''
            filter: (semester)->
                exp = new RegExp @value
                for id in semester.subject_ids
                    en = subjectMap[id].title_en.match exp
                    ja = subjectMap[id].title_ja.match exp
                    if en or ja
                        return true
                false


        if $stateParams.class_year
            if current = $scope.classYearFilter.finfBySlug $stateParams.class_year
                current.active true

        if $stateParams.subject
            selectedSubject = $scope.subjects.retrieve $stateParams.subject, 'title_en'
            $scope.subjectFilter.value = selectedSubject.title_ja


        $scope.semesters.setFilter semesterFilter


.controller 'AdminSemesterDetailCtrl',
    ($scope, Semester, $state, $stateParams, Notify, NotFound) ->
        if not $scope.semester = $scope.semesters.retrieve $stateParams.id
            NotFound()

.controller 'AdminSemesterEditCtrl',
    ($scope, Semester, $state, $stateParams, Notify) ->
        $scope.editing = $scope.semester?.id?
        $scope.title = if $scope.editing then '編集' else '新規作成'

        $scope.deleting = false

        if $scope.editing
            $scope.new_semester = angular.copy $scope.semester
        else
            $scope.new_semester = new Semester()
            $scope.new_semester.subject_ids = []

        $scope.doSaveSemester = ()->
            if $scope.editing
                $scope.new_semester.$update {}, (data)->
                    $scope.semesters.set data
                    $state.go 'admin.semester.detail', {id: data.id}
                    Notify '保存しました。'
            else
                $scope.new_semester.$save {}, (data)->
                    $scope.semesters.set data
                    $state.go 'admin.semester.detail', {id: data.id}
                    Notify '新規作成しました。'

        $scope.doDeleteSemester = ()->
            $scope.semester.$remove {}, (data)->
                $scope.semesters.del $scope.semester
                $state.go 'admin.semester'
                Notify '削除しました。', type: 'danger'

        $scope.deleteSemester = ()->
            if $scope.deleting
                $scope.doDeleteSemester()
            else
                Notify 'もう一度クリックすると削除します。', type: 'danger'
                $scope.deleting = true

        $scope.stopDeleting = ->
            $scope.deleting = false
            Notify '削除を中断しました。', type: 'warning'


        $scope.subjectCheckboxChange = (subject)->
            idx = $scope.new_semester.subject_ids.indexOf subject.id
            if idx > -1
                $scope.new_semester.subject_ids.splice idx, 1
            else
                $scope.new_semester.subject_ids.push subject.id

