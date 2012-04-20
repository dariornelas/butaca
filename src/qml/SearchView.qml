/**************************************************************************
 *    Butaca
 *    Copyright (C) 2011 Simon Pena <spena@igalia.com>
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 **************************************************************************/

import QtQuick 1.1
import com.nokia.meego 1.0
import com.nokia.extras 1.0
import 'constants.js' as UIConstants
import "butacautils.js" as BUTACA
import "storage.js" as Storage

Page {
    id: searchView
    tools: ToolBarLayout {
        ToolIcon {
            iconId: 'toolbar-back'
            onClicked: appWindow.pageStack.pop()
        }
    }

    orientationLock: PageOrientation.LockPortrait

    property alias searchTerm: searchInput.text
    property bool useSimpleDelegate : searchCategory.checkedButton !== movieSearch
    property bool loading: false

    property ListModel localModel: ListModel { }

    Component.onCompleted: {
        searchInput.forceActiveFocus()
    }

    Header {
        id: header
        //: Search
        text: qsTr('btc-search-header')
    }

    TextField {
        id: searchInput
        //: Enter search terms
        placeholderText: qsTr('btc-search-placeholder')

        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            margins: UIConstants.DEFAULT_MARGIN
        }

        platformSipAttributes: SipAttributes {
            actionKeyIcon: '/usr/share/themes/blanco/meegotouch/icons/icon-m-toolbar-search-selected.png'
        }

        Keys.onReturnPressed: {
            doSearch()
        }

        Image {
            id: clearText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            source: searchInput.text ?
                        'image://theme/icon-m-input-clear' :
                        ''
        }

        MouseArea {
            id: searchInputMouseArea
            anchors.fill: clearText
            onClicked: {
                inputContext.reset()
                searchInput.text = ''
            }
        }
    }

    ButtonRow {
        id: searchCategory
        anchors {
            top: searchInput.bottom
            left: parent.left
            right: parent.right
            margins: UIConstants.DEFAULT_MARGIN
        }

        Button {
            id: movieSearch
            //: Movies
            text: qsTr('btc-movies')
        }

        Button {
            id: peopleSearch
            //: People
            text: qsTr('btc-people')
        }

        onCheckedButtonChanged: {
            doSearch()
        }
    }

    Loader {
        id: resultsListLoader
        sourceComponent: useSimpleDelegate ? peopleListWrapper : moviesListWrapper
        anchors {
            topMargin: UIConstants.DEFAULT_MARGIN
            top: searchCategory.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
    }

    PeopleModel {
        id: peopleModel
        source: ''
        onStatusChanged: {
            if (status == XmlListModel.Ready) {
                populateModel(peopleModel, localModel, BUTACA.TMDbPerson)
            }
        }
    }

    MultipleMoviesModel {
        id: moviesModel
        source: ''
        onStatusChanged: {
            if (status == XmlListModel.Ready) {
                populateModel(moviesModel, localModel, BUTACA.TMDbMovie)
            }
        }
    }

    Component {
        id: peopleListWrapper

        Item {
            id: innerWrapper

            ListView {
                id: peopleList
                clip: true
                anchors.fill: parent
                model: searchView.localModel
                delegate: MyListDelegate {
                    width: parent.width
                    title: model.title
                    onClicked: searchView.handleClicked(index)
                }
            }

            ScrollDecorator {
                id: scrollDecorator
                flickableItem: peopleList
            }
        }
    }

    Component {
        id: moviesListWrapper

        Item {
            id: innerWrapper

            ListView {
                id: moviesList
                clip: true
                anchors.fill: parent
                model: searchView.localModel
                delegate: MultipleMoviesDelegate {
                    onClicked: searchView.handleClicked(index)
                }
            }

            ScrollDecorator {
                id: scrollDecorator
                flickableItem: moviesList
            }
        }
    }

    NoContentItem {
        id: noResults
        anchors {
            top: searchCategory.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: UIConstants.DEFAULT_MARGIN
        }
        visible: false
        text: ''
    }

    BusyIndicator {
        id: busyIndicator
        visible: running
        running: loading
        platformStyle: BusyIndicatorStyle { size: 'large' }
        anchors.centerIn: noResults
    }

    states: [
        State {
            name: 'loadingState'
            when: peopleModel.status == XmlListModel.Loading ||
                  moviesModel.status == XmlListModel.Loading
            PropertyChanges {
                target: busyIndicator
                running: true
            }
        },
        State {
            name: 'errorState'
            when: peopleModel.status == XmlListModel.Error ||
                  moviesModel.status == XmlListModel.Error
            PropertyChanges {
                target: noResults
                visible: true
                text: 'There was an error performing the search'
            }
        },
        State {
            name: 'notFoundState'
            when: (peopleModel.status == XmlListModel.Ready ||
                   moviesModel.status == XmlListModel.Ready) &&
                  (peopleModel.source != '' || moviesModel.source != '') &&
                  localModel.count === 0
            PropertyChanges {
                target: noResults
                visible: true
                text: 'Not found'
            }
        },
        State {
            name: 'emptyState'
            when: (peopleModel.status == XmlListModel.Ready ||
                   moviesModel.status == XmlListModel.Ready) &&
                  (peopleModel.source  == '' && moviesModel.source == '') &&
                  !searchInput.text
            PropertyChanges {
                target: noResults
                visible: true
                text: 'Enter search terms'
            }
        }
    ]

    function handleClicked(index) {
        var element = localModel.get(index)
        switch (element.type) {
        case 'TMDbMovie':
            pageStack.push(movieView,
                           {
                               movie: element
                           })
            break
        case 'TMDbPerson':
            pageStack.push(personView,
                           {
                               person: element
                           })
            break
        }
    }

    function populateModel(sourceModel, destinationModel, ObjectConstructor) {
        if (sourceModel.count > 0) {
            for (var i = 0; i < sourceModel.count; i ++) {
                destinationModel.append(new ObjectConstructor(sourceModel.get(i)))
            }
        }
        loading = false
    }

    function doSearch() {
        peopleModel.source = ''
        moviesModel.source = ''
        localModel.clear()
        if (searchTerm) {
            loading = true
            if (searchCategory.checkedButton === movieSearch) {
                moviesModel.source = BUTACA.getTMDbSource(BUTACA.TMDB_MOVIE_SEARCH, appLocale, searchTerm)
            } else if (searchCategory.checkedButton === peopleSearch) {
                peopleModel.source = BUTACA.getTMDbSource(BUTACA.TMDB_PERSON_SEARCH, appLocale, searchTerm)
            }
            resultsListLoader.forceActiveFocus()
        }
    }
}
