import QtQuick 1.1
import com.nokia.meego 1.0
import 'butacautils.js' as BUTACA
import 'constants.js' as UIConstants

Page {
    id: movieView

    orientationLock: PageOrientation.LockPortrait

    tools: ToolBarLayout {
        ToolIcon {
            iconId: 'toolbar-back'
            onClicked: {
                appWindow.pageStack.pop()
            }
        }
    }

    property variant movie: ''
    property string tmdbId: parsedMovie.tmdbId
    property bool loading: false

    QtObject {
        id: parsedMovie

        // Part of the lightweight movie object
        property string tmdbId: ''
        property string name: ''
        property string originalName: ''
        property string alternativeName: ''
        property string released: ''
        property double rating: 0
        property int votes: 0
        property string overview: ''
        property string poster: ''
        property string url: ''

        // Part of the full movie object
        property string imdbId: ''
        property string tagline: ''
        property string trailer: ''
        property string revenue: ''
        property string budget: ''
        property int runtime: 0
        property string certification: ''
        property string homepage: ''

        function updateWithLightWeightMovie(movie) {
            tmdbId = movie.id
            name = movie.name
            released = movie.released
            rating = movie.rating
            votes = movie.votes
            overview = movie.overview
            if (movie.poster)
                poster = movie.poster
        }

        function updateWithFullWeightMovie(movie) {
            if (!movieView.movie) {
                updateWithLightWeightMovie(movie)
            }
            movieView.movie = ''

            if (movie.trailer)
                trailer = movie.trailer
            if (movie.homepage)
                homepage = movie.homepage
            if (movie.revenue)
                revenue = movie.revenue
            if (movie.budget)
                budget = movie.budget
            if (movie.certification)
                certification = movie.certification
            if (movie.alternativeName)
                alternativeName = movie.alternative_name
            if (movie.tagline)
                tagline = movie.tagline
            if (movie.runtime)
                runtime = movie.runtime

            movie.cast.sort(sortCastMembers)

            populateModel(movie, 'genres', genresModel)
            populateModel(movie, 'studios', studiosModel)
            populatePostersModel(movie)
            populateModel(movie, 'cast', crewModel)

            if (postersModel.get(0).sizes['cover'].url)
                poster = postersModel.get(0).sizes['cover'].url
        }
    }

    function sortCastMembers(oneItem, theOther) {
        return oneItem.cast_id - theOther.cast_id
    }

    function populatePostersModel(movie) {
        var i = 0
        var image
        while (i < movie.posters.length) {
            if (image && image.id === movie.posters[i].image.id) {
                image.addSize(movie.posters[i].image)
            } else {
                if (image) postersModel.append(image)
                image = new BUTACA.TMDbImage(movie.posters[i])
            }
            i ++
        }
    }

    function populateModel(movie, movieProperty, model) {
        if (movie[movieProperty]) {
            for (var i = 0; i < movie[movieProperty].length; i ++) {
                if (movieProperty === 'cast') {
                    var castPerson = new BUTACA.TMDbCrewPerson(movie[movieProperty][i])
                    if (castPerson.job === 'Actor') {
                        castModel.append(castPerson)
                    }
                    model.append(castPerson)
                } else {
                    model.append(movie[movieProperty][i])
                }
            }
        }
    }

    Component.onCompleted: {
        if (movie) {
            var theMovie = new BUTACA.TMDbMovie(movie)
            parsedMovie.updateWithLightWeightMovie(theMovie)
        }

        if (tmdbId !== -1) {
            asyncWorker.sendMessage({
                                        action: BUTACA.REMOTE_FETCH_REQUEST,
                                        tmdbId: tmdbId,
                                        tmdbType: 'movie'
                                    })
        }
    }

    // Several ListModels are used.
    // * Genres stores the genres / categories which best describe the movie. When
    //   browsing by genre, the movie will have at least the genre we were navigating
    // * Studios stores the company which produced the film
    // * Posters stores all the media for this particular film. The media is
    //   processed, so each particular image keeps all available resolutions
    // * Cast and crew are separated from each other, so we can be more specific
    //   in the movie preview

    ListModel {
        id: genresModel
    }

    ListModel {
        id: studiosModel
    }

    ListModel {
        id: postersModel
    }

    ListModel {
        id: castModel
    }

    ListModel {
        id: crewModel
    }

    Component {
        id: galleryView

        Page {
            property ListModel galleryViewModel

            tools: ToolBarLayout {
                ToolIcon {
                    iconId: 'toolbar-back'
                    onClicked: {
                        appWindow.pageStack.pop()
                    }
                }
            }

            GridView {
                id: grid
                anchors.fill: parent
                cellHeight: 160
                cellWidth: 160
                model: galleryViewModel
                clip: true
                delegate: Rectangle {
                    height: grid.cellHeight
                    width: grid.cellWidth
                    clip: true
                    color: '#2d2d2d'

                    Image {
                        anchors {
                            fill: parent
                            margins: UIConstants.PADDING_SMALL
                        }
                        source: sizes['w154'].url
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }
        }
    }

    Flickable {
        id: movieFlickableWrapper
        anchors {
            fill: parent
            margins: UIConstants.DEFAULT_MARGIN
        }
        contentHeight: movieContent.height
        visible: !loading

        Column {
            id: movieContent
            width: parent.width
            spacing: UIConstants.DEFAULT_MARGIN

            Header {
                text: parsedMovie.name + ' (' + getYearFromDate(parsedMovie.released) + ')'
            }

            Row {
                id: row
                width: parent.width

                Image {
                    id: image
                    width: 160
                    height: 236
                    source: parsedMovie.poster
                    fillMode: Image.PreserveAspectFit
                }

                Column {
                    width: parent.width - image.width

                    MyEntryHeader {
                        anchors {
                            left: parent.left
                            right: parent.right
                            margins: UIConstants.DEFAULT_MARGIN
                        }
                        headerFontSize: UIConstants.FONT_SLARGE
                        text: parsedMovie.name + ' (' + getYearFromDate(parsedMovie.released) + ')'
                    }

                    Label {
                        id: ratedAndRuntimeLabel
                        anchors {
                            left: parent.left
                            right: parent.right
                            margins: UIConstants.DEFAULT_MARGIN
                        }
                        platformStyle: LabelStyle {
                            fontPixelSize: UIConstants.FONT_LSMALL
                        }
                        wrapMode: Text.WordWrap
                        text: 'Rated ' + parsedMovie.certification + ', ' + parseRuntime(parsedMovie.runtime)
                    }

                    Item {
                        height: UIConstants.DEFAULT_MARGIN
                        width: parent.width
                    }

                    Label {
                        id: taglineLabel
                        anchors {
                            left: parent.left
                            right: parent.right
                            margins: UIConstants.DEFAULT_MARGIN
                        }
                        platformStyle: LabelStyle {
                            fontPixelSize: UIConstants.FONT_DEFAULT
                            fontFamily: UIConstants.FONT_FAMILY_LIGHT
                        }
                        font.italic: true
                        wrapMode: Text.WordWrap
                        text: parsedMovie.tagline
                    }
                }
            }

            Row {
                id: movieRatingSection

                Label {
                    id: ratingLabel
                    platformStyle: LabelStyle {
                        fontPixelSize: UIConstants.FONT_XXLARGE
                        fontFamily: UIConstants.FONT_FAMILY_TABULAR
                    }
                    text: parsedMovie.rating
                }

                Label {
                    anchors.verticalCenter: ratingLabel.verticalCenter
                    platformStyle: LabelStyle {
                        fontPixelSize: UIConstants.FONT_XLARGE
                        fontFamily: UIConstants.FONT_FAMILY_TABULAR
                    }
                    color: UIConstants.COLOR_SECONDARY_FOREGROUND
                    text: '/10'
                }

                Item {
                    height: UIConstants.DEFAULT_MARGIN
                    width: UIConstants.DEFAULT_MARGIN
                }

                MyRatingIndicator {
                    anchors.verticalCenter: ratingLabel.verticalCenter
                    ratingValue: parsedMovie.rating
                    maximumValue: 10
                    count: parsedMovie.votes
                }
            }

            Column {
                width: parent.width

                Rectangle {
                    width: parent.width
                    height: 1
                    color: UIConstants.COLOR_SECONDARY_FOREGROUND
                }

                Item {
                    width: parent.width
                    height: 140

                    BorderImage {
                        anchors.fill: parent
                        visible: galleryMouseArea.pressed
                        source: 'image://theme/meegotouch-list-fullwidth-inverted-background-pressed-vertical-center'
                    }

                    Flow {
                        anchors {
                            left: parent.left
                            leftMargin: UIConstants.PADDING_LARGE
                            verticalCenter: parent.verticalCenter
                        }
                        width: parent.width - galleryMoreIndicator.width
                        height: parent.height
                        spacing: UIConstants.PADDING_LARGE

                        Repeater {
                            model: Math.min(4, postersModel.count)
                            delegate: Image {
                                    width: 92; height: 138
                                    opacity: galleryMouseArea.pressed ? 0.5 : 1
                                    fillMode: Image.PreserveAspectFit
                                    source: postersModel.get(index).sizes['thumb'].url
                                }
                        }
                    }

                    MyMoreIndicator {
                        id: galleryMoreIndicator
                        anchors {
                            right: parent.right
                            rightMargin: UIConstants.DEFAULT_MARGIN
                            verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: galleryMouseArea
                        anchors.fill: parent
                        onClicked: {
                            appWindow.pageStack.push(galleryView, { galleryViewModel: postersModel })
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: UIConstants.COLOR_SECONDARY_FOREGROUND
                    visible: parsedMovie.trailer
                }

                MyListDelegate {
                    title: 'Watch Trailer'
                    titleSize: UIConstants.FONT_SLARGE

                    iconSource: 'qrc:/resources/icon-m-common-video-playback.png'
                    visible: parsedMovie.trailer

                    onClicked: Qt.openUrlExternally(parsedMovie.trailer)
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: UIConstants.COLOR_SECONDARY_FOREGROUND
                }
            }

            Item {
                id: movieOverviewSection
                width: parent.width
                height: expanded ? actualSize : Math.min(actualSize, collapsedSize)
                clip: true

                property int actualSize: overviewColumn.height
                property int collapsedSize: 160
                property bool expanded: false

                Column {
                    id: overviewColumn
                    width: parent.width

                    MyEntryHeader {
                        width: parent.width
                        //: Overview:
                        text: qsTr('btc-overview')
                    }

                    Label {
                        id: overviewContent
                        width: parent.width
                        platformStyle: LabelStyle {
                            fontPixelSize: UIConstants.FONT_LSMALL
                            fontFamily: UIConstants.FONT_FAMILY_LIGHT
                        }
                        text: parsedMovie.overview
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignJustify
                    }
                }
            }

            Item {
                id: overviewExpander
                height: 24
                width: parent.width
                visible: movieOverviewSection.actualSize > movieOverviewSection.collapsedSize

                MouseArea {
                    anchors.fill: parent
                    onClicked: movieOverviewSection.expanded = !movieOverviewSection.expanded
                }

                MyMoreIndicator {
                    id: moreIndicator
                    anchors.centerIn: parent
                    rotation: movieOverviewSection.expanded ? -90 : 90

                    Behavior on rotation {
                        NumberAnimation { duration: 200 }
                    }
                }
            }

            Column {
                id: movieReleasedSection
                width: parent.width

                MyEntryHeader {
                    width: parent.width
                    //: Release date:
                    text: qsTr('btc-release-date')
                }

                Label {
                    id: release
                    width: parent.width
                    platformStyle: LabelStyle {
                        fontPixelSize: UIConstants.FONT_LSMALL
                        fontFamily: UIConstants.FONT_FAMILY_LIGHT
                    }
                    text: Qt.formatDate(parseDate(parsedMovie.released), Qt.DefaultLocaleLongDate)
                }
            }

            Column {
                id: movieGenresSection
                width: parent.width

                MyEntryHeader {
                    width: parent.width
                    text: 'Genre'
                }

                Flow {
                    width: parent.width

                    Repeater {
                        model: genresModel
                        delegate: Label {
                                platformStyle: LabelStyle {
                                    fontPixelSize: UIConstants.FONT_LSMALL
                                    fontFamily: UIConstants.FONT_FAMILY_LIGHT
                                }
                                text: genresModel.get(index).name + (index !== genresModel.count - 1 ? ', ' : '')
                            }
                    }
                }
            }

            Column {
                id: movieStudiosSection
                width: parent.width

                MyEntryHeader {
                    width: parent.width
                    text: 'Studios'
                }

                Flow {
                    width: parent.width

                    Repeater {
                        model: studiosModel
                        delegate: Label {
                                platformStyle: LabelStyle {
                                    fontPixelSize: UIConstants.FONT_LSMALL
                                    fontFamily: UIConstants.FONT_FAMILY_LIGHT
                                }
                                text: studiosModel.get(index).name + (index !== studiosModel.count - 1 ? ', ' : '')
                            }
                    }
                }
            }

            Column {
                id: movieCastSection
                width: parent.width

                MyEntryHeader {
                    width: parent.width
                    text: 'Cast'
                }

                Repeater {
                    width: parent.width
                    model: Math.min(4, castModel.count)
                    delegate: MyListDelegate {
                        smallSize: true

                        iconSource: castModel.get(index).profile ?
                                        castModel.get(index).profile :
                                        'qrc:/resources/person-placeholder.svg'

                        title: castModel.get(index).name
                        titleFontFamily: UIConstants.FONT_FAMILY_BOLD
                        titleSize: UIConstants.FONT_LSMALL

                        subtitle: 'as ' + castModel.get(index).character
                        subtitleSize: UIConstants.FONT_XSMALL
                        subtitleFontFamily: UIConstants.FONT_FAMILY_LIGHT
                    }
                }

                MyListDelegate {
                    smallSize: true
                    title: 'Full Cast'
                    titleSize: UIConstants.FONT_LSMALL
                    titleFontFamily: UIConstants.FONT_FAMILY_BOLD
                }
            }

            Column {
                id: movieCrewSection
                width: parent.width

                MyEntryHeader {
                    width: parent.width
                    text: 'Crew'
                }

                Repeater {
                    width: parent.width
                    model: Math.min(4, crewModel.count)
                    delegate: MyListDelegate {
                        smallSize: true

                        iconSource: crewModel.get(index).profile ?
                                        crewModel.get(index).profile :
                                        'qrc:/resources/person-placeholder.svg'

                        title: crewModel.get(index).name
                        titleFontFamily: UIConstants.FONT_FAMILY_BOLD
                        titleSize: UIConstants.FONT_LSMALL

                        subtitle: crewModel.get(index).job
                        subtitleSize: UIConstants.FONT_XSMALL
                        subtitleFontFamily: UIConstants.FONT_FAMILY_LIGHT
                    }
                }

                MyListDelegate {
                    smallSize: true
                    title: 'Full Cast & Crew'
                    titleSize: UIConstants.FONT_LSMALL
                    titleFontFamily: UIConstants.FONT_FAMILY_BOLD
                }
            }
        }
    }

    ScrollDecorator {
        flickableItem: movieFlickableWrapper
        anchors.rightMargin: -UIConstants.DEFAULT_MARGIN
    }

    function getYearFromDate(date) {
        if (date) {
            var dateParts = date.split('-')
            return dateParts[0]
        }
        return ' - '
    }

    function parseRuntime(runtime) {
        var hours = parseInt(runtime / 60)
        var minutes = (runtime % 60)

        var str = hours + ' h ' + minutes + ' m'
        return str
    }

    function parseDate(date) {
        if (date) {
            var dateParts = date.split('-')
            var parsedDate = new Date(dateParts[0], dateParts[1] - 1, dateParts[2])
            return parsedDate
        }
        return ''
    }

    function handleMessage(messageObject) {
        if (messageObject.action === BUTACA.REMOTE_FETCH_RESPONSE) {
            loading = false
            var fullMovie = JSON.parse(messageObject.response)[0]
            parsedMovie.updateWithFullWeightMovie(fullMovie)
        } else {
            console.debug('Unknown action response: ', messageObject.action)
        }

    }

    BusyIndicator {
        id: movieBusyIndicator
        anchors.centerIn: parent
        visible: running
        running: loading
        platformStyle: BusyIndicatorStyle {
            size: 'large'
        }
    }

    WorkerScript {
        id: asyncWorker
        source: 'workerscript.js'
        onMessage: {
            handleMessage(messageObject)
        }
    }
}
