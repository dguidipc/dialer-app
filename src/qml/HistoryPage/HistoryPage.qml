/*
 * Copyright 2012-2013 Canonical Ltd.
 *
 * This file is part of dialer-app.
 *
 * dialer-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * dialer-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Ubuntu.Components 1.1
import Ubuntu.Components.ListItems 0.1 as ListItem
import Ubuntu.History 0.1
import Ubuntu.Telephony 0.1
import Ubuntu.Contacts 0.1
import "dateUtils.js" as DateUtils

Page {
    id: historyPage
    objectName: "historyPage"

    property string searchTerm
    property int delegateHeight: delegate.height
    property bool fullView: currentIndex == -1
    property alias currentIndex: historyList.currentIndex
    property alias selectionMode: historyList.isInSelectionMode

    function activateCurrentIndex() {
        if (historyList.currentItem) {
            historyList.currentItem.activate();
        }
    }

    title: selectionMode ? i18n.tr("Select") : i18n.tr("Recent")
    anchors.fill: parent
    active: false

    head.sections.model: [ i18n.tr("All"), i18n.tr("Missed") ]

    Rectangle {
        anchors.fill: parent
        color: Theme.palette.normal.background
    }

    states: [
        PageHeadState {
            name: "select"
            when: selectionMode
            head: historyPage.head

            backAction: Action {
                objectName: "selectionModeCancelAction"
                iconName: "close"
                onTriggered: historyList.cancelSelection()
            }

            actions: [
                Action {
                    objectName: "selectionModeSelectAllAction"
                    iconName: "select"
                    onTriggered: {
                        if (historyList.selectedItems.count === historyList.count) {
                            historyList.clearSelection()
                        } else {
                            historyList.selectAll()
                        }
                    }
                },
                Action {
                    objectName: "selectionModeDeleteAction"
                    enabled: historyList.selectedItems.count > 0
                    iconName: "delete"
                    onTriggered: historyList.endSelection()
                }
            ]
        }
    ]

    onActiveChanged: {
        if (!active) {
            if (selectionMode) {
                historyList.cancelSelection();
            }
            historyList.resetSwipe()
            historyList.positionViewAtBeginning()
        }

    }

    // Use this delegate just to calculate the height
    HistoryDelegate {
        id: delegate
        visible: false
        property variant model: Item {
            property string senderId: "dummy"
            property variant participants: ["dummy"]
        }
    }

    // FIXME: this is a big hack to fix the placing of the listview items
    // when dragging the bottom edge
    flickable: null
    Connections {
        target: pageStack
        onDepthChanged: {
            if (pageStack.depth > 1)
                flickable = historyList
        }
    }

    Connections {
        target: head.sections
        onSelectedIndexChanged: {
            // NOTE: be careful on changing the way filters are assigned, if we create a
            // binding on head.sections, we might get weird results when the page moves to the bottom
            if (pageStack.depth > 1) {
                if (head.sections.selectedIndex == 0) {
                    historyEventModel.filter = emptyFilter;
                } else {
                    historyEventModel.filter = missedFilter;
                }
            }
        }
    }

    HistoryFilter {
        id: emptyFilter
    }

    HistoryFilter {
        id: missedFilter
        filterProperty: "missed"
        filterValue: true
    }

    HistoryGroupedEventsModel {
        id: historyEventModel
        groupingProperties: ["participants", "date"]
        type: HistoryThreadModel.EventTypeVoice
        sort: HistorySort {
            sortField: "timestamp"
            sortOrder: HistorySort.DescendingOrder
        }
        filter: emptyFilter
    }

    MultipleSelectionListView {
        id: historyList
        objectName: "historyList"

        property var _currentSwipedItem: null

        function resetSwipe()
        {
            if (_currentSwipedItem) {
                _currentSwipedItem.resetSwipe()
                _currentSwipedItem = null
            }
        }

        function _updateSwipeState(item)
        {
            if (item.swipping) {
                return
            }

            if (item.swipeState !== "Normal") {
                if (_currentSwipedItem !== item) {
                    if (_currentSwipedItem) {
                        _currentSwipedItem.resetSwipe()
                    }
                    _currentSwipedItem = item
                }
            } else if (item.swipeState !== "Normal" && _currentSwipedItem === item) {
                _currentSwipedItem = null
            }
        }

        Connections {
            target: Qt.application
            onActiveChanged: {
                if (!Qt.application.active) {
                    historyList.currentIndex = -1
                }
            }
        }

        currentIndex: -1
        anchors.fill: parent
        listModel: historyEventModel

        onSelectionDone: {
            for (var i=0; i < items.count; i++) {
                var event = items.get(i).model
                historyEventModel.removeEvent(event.accountId, event.threadId, event.eventId, event.type)
            }
        }
        onIsInSelectionModeChanged: {
            if (isInSelectionMode && _currentSwipedItem) {
                _currentSwipedItem.resetSwipe()
                _currentSwipedItem = null
            }
        }

        Component {
            id: sectionComponent
            Label {
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    right: parent.right
                    rightMargin: units.gu(2)
                }
                text: DateUtils.friendlyDay(section)
                height: units.gu(5)
                fontSize: "medium"
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
                ListItem.ThinDivider {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        bottomMargin: units.gu(0.5)
                    }
                }
            }
        }

        section.property: "date"
        section.delegate: fullView ? sectionComponent : null

        listDelegate: delegateComponent
        displaced: Transition {
            UbuntuNumberAnimation {
                property: "y"
            }
        }

        remove: Transition {
            ParallelAnimation {
                UbuntuNumberAnimation {
                    property: "height"
                    to: 0
                }

                UbuntuNumberAnimation {
                    properties: "opacity"
                    to: 0
                }
                ScriptAction {
                    script: {
                        historyList.resetSwipe()
                    }
                }
            }
        }

        Component {
            id: delegateComponent
            HistoryDelegate {
                id: historyDelegate
                objectName: "historyDelegate" + index

                anchors{
                    left: parent.left
                    right: parent.right
                }

                selected: historyList.isSelected(historyDelegate)
                selectionMode: historyList.isInSelectionMode
                isFirst: model.index === 0
                locked: historyList.isInSelectionMode
                fullView: historyPage.fullView
                active: ListView.isCurrentItem

                onItemPressAndHold: {
                    if (!historyList.isInSelectionMode) {
                        historyList.startSelection()
                    }
                    historyList.selectItem(historyDelegate)
                }

                onItemClicked: {
                    if (historyList.isInSelectionMode) {
                        if (!historyList.selectItem(historyDelegate)) {
                            historyList.deselectItem(historyDelegate)
                        }
                        return
                    }

                    historyDelegate.activate()
                }

                onSwippingChanged: historyList._updateSwipeState(historyDelegate)
                onSwipeStateChanged: historyList._updateSwipeState(historyDelegate)

                leftSideAction: Action {
                    iconName: "delete"
                    text: i18n.tr("Delete")
                    onTriggered:  {
                        var events = model.events;
                        for (var i in events) {
                            historyEventModel.removeEvent(events[i].accountId, events[i].threadId, events[i].eventId, events[i].type)
                        }
                    }
                }
                property bool knownNumber: participants[0] != "x-ofono-private" && participants[0] != "x-ofono-unknown"
                rightSideActions: [
                    Action {
                        iconName: "info"
                        text: i18n.tr("Details")
                        onTriggered: {
                            pageStack.push(Qt.resolvedUrl("HistoryDetailsPage.qml"),
                                                          { phoneNumber: participants[0],
                                                            events: model.events,
                                                            eventModel: historyEventModel})
                        }
                    },
                    Action {
                        iconName: unknownContact ? "contact-new" : "stock_contact"
                        text: i18n.tr("Contact Details")
                        onTriggered: {
                            if (unknownContact) {
                                mainView.addNewPhone(phoneNumber)
                            } else {
                                mainView.viewContact(contactId)
                            }
                        }
                        visible: knownNumber
                        enabled: knownNumber
                    },
                    Action {
                        iconName: "message"
                        text: i18n.tr("Send message")
                        onTriggered: {
                            mainView.sendMessage(phoneNumber)
                        }
                        visible: knownNumber
                        enabled: knownNumber
                    }
                ]
            }
        }
    }

    Scrollbar {
        flickableItem: historyList
        align: Qt.AlignTrailing
    }
}
