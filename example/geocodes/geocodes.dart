import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:react/react.dart' as react;
import 'package:react/react_dom.dart' as react_dom;
import 'package:react/react_client.dart';


/**
 * Hello,
 *
 * This is the Dart portion of the tutorial for the Dart react package.
 *
 * We'll go through a simple app that queries the Google Maps API and shows the result to the user.
 * It also stores the search history and allows the user to reload past queries.
 *
 * In this file you'll find the structure and the logic of the app. There is also a `geocodes.html` file which contains
 * the mount point.
 *
 * Be sure that you understand the basic concepts of [React](http://facebook.github.io/react/) before reading this
 * tutorial.
 *
 * Enjoy!
 */



/// Divide your app into components and conquer!
///
/// This is the first custom [Component].
///
/// It is just an HTML `<tr>` element displaying a single API response to the user.
class _GeocodesResultItem extends react.Component {

  /// The only function you must implement in the custom component is [render].
  ///
  /// Every [Component] has a map of properties called [Component.props]. It can be specified during creation.
  @override
  render() {
    return react.tr({}, [
      react.td({}, props['lat']),
      react.td({}, props['lng']),
      react.td({}, props['formatted'])
    ]);
  }
}

/// Now we need to tell ReactJS that our custom [Component] exists by calling [registerComponent].
///
/// As a reward, it gives us a function, that takes the properties and returns our element. You'll see it in action
/// shortly.
///
/// This is the only correct way to create a [Component]. Do not use the constructor!
var geocodesResultItem = react.registerComponent(() => new _GeocodesResultItem());


/// In this component we'll build an HTML `<table>` element full of the `<tr>` elements generated by
/// [_GeocodesResultItem]
class _GeocodesResultList extends react.Component {
  @override
  render() {
    // Built-in HTML DOM components also have props - which correspond to HTML element attributes.
    return react.div({'id': 'results'}, [
      react.h2({}, 'Results:'),
      // However, `class` is a keyword in javascript, therefore `className` is used instead
      react.table({'className': 'table'}, [
        react.thead({}, [
          react.th({}, 'Latitude'),
          react.th({}, 'Longitude'),
          react.th({}, 'Address')
        ]),
        react.tbody({},
          // The second argument contains the body of the component (as you have already seen).
          //
          // It can be a String, a Component or an Iterable.
          props['data'].map(
            (item) => geocodesResultItem({
              'lat': item['geometry']['location']['lat'],
              'lng': item['geometry']['location']['lng'],
              'formatted': item['formatted_address']
            })
          )
        )
      ])
    ]);
  }
}

var geocodesResultList = react.registerComponent(() => new _GeocodesResultList());


/// In this [Component] we'll build a search form.
///
/// This [Component] illustrates that:
///
/// > The functions can be [Component] parameters _(handy for callbacks)_
///
/// > The DOM [Element]s can be accessed using [ref]s.
class _GeocodesForm extends react.Component {
  var searchInputInstance;

  @override
  render() {
    return react.div({}, [
      react.h2({}, 'Search'),
      // Component function is passed as callback
      react.form({
        'className': 'form-inline',
        'onSubmit': onFormSubmit
      }, [
        react.label({
          'htmlFor': 'addressInput',
          'className': 'sr-only',
        }, 'Enter address'),
        react.input({
          'id': 'addressInput',
          'className': 'form-control',
          'type': 'text',
          'placeholder': 'Enter address',
          // Input is referenced to access it's value
          'ref': (searchInputInstance) { this.searchInputInstance = searchInputInstance; }
        }),
        react.span({}, '\u00a0'),
        react.button({
          'className': 'btn btn-primary',
          'type': 'submit'
        }, 'Submit'),
      ])
    ]);
  }

  /// Handle form submission via `props.onSubmit`
  onFormSubmit(react.SyntheticEvent event) {
      event.preventDefault();
      InputElement inputElement = react_dom.findDOMNode(searchInputInstance);
      // The input's value is accessed.
      var address = inputElement.value;
      inputElement.value = '';
      // Call the callback from the parent element is called.
      props['submitter'](address);
    }
}

var geocodesForm = react.registerComponent(() => new _GeocodesForm());


/// Renders an HTML `<li>` to be used as a child within the [_GeocodesHistoryList].
class _GeocodesHistoryItem extends react.Component {
  reload(e) {
    props['reloader'](props['query']);
  }

  @override
  render() {
    return react.li({}, [
      react.button({
        'className': 'btn btn-sm btn-default',
        'onClick': reload
      }, 'Reload'),
      ' (${props['status']}) ${props['query']}'
    ]);
  }
}

var geocodesHistoryItem = react.registerComponent(() => new _GeocodesHistoryItem());


/// Renders the "history list"
///
/// NOTE: It just passes the callback from the parent.
class _GeocodesHistoryList extends react.Component {
  @override
  render() {
    return react.div({}, [
      react.h3({}, 'History:'),
      react.ul({},
        new List.from(props['data'].keys.map(
          (key) => geocodesHistoryItem({
            'key': key,
            'query': props['data'][key]['query'],
            'status': props['data'][key]['status'],
            'reloader': props['reloader']
          })
        )).reversed
      )
    ]);
  }
}

var geocodesHistoryList = react.registerComponent(() => new _GeocodesHistoryList());


/// The root [Component] of our application.
///
/// Introduces [state]. Both [state] and [props] are valid locations to store [Component] data.
///
/// However, there are some key differences to note:
///
/// > [props] can contain data dictated by the parent component
///
/// > [state] is an internal storage of the component that can't be accessed by the parent.
///
/// > When [state] is changed, the component will re-render.
///
/// It's a common practice to store the application data in the [state] of the root [Component]. It will re-render
/// every time the state is changed. However, it is not required - you can also use normal variables and re-render
/// manually if you wish.
///
/// When the request is sent, it has `pending` status in the history. This changes to `OK` or `error` when the answer
/// _(or timeout)_ comes. If the new request is sent meanwhile, the old one is cancelled.
class _GeocodesApp extends react.Component {
  @override
  getInitialState() => {
    'shown_addresses': [], // Data from last query.
    'history': {} // Map of past queries.
  };

  /// The id of the last query.
  var last_id = 0;

  /// Sends the [addressQuery] to the API and processes the result
  newQuery(String addressQuery) {

    // Once the query is being sent, it appears in the history and is given an id.
    var id = addQueryToHistory(addressQuery);

    // Prepare the URL
    addressQuery = Uri.encodeQueryComponent(addressQuery);
    var path = 'https://maps.googleapis.com/maps/api/geocode/json?address=$addressQuery';

    // Send the request
    HttpRequest.getString(path)
        .then((value) =>
            // Delay the answer 2 more seconds, for test purposes
            new Future.delayed(new Duration(seconds: 2), () => value)
        )
        .then((String raw) {
          // Is this the answer to the last request?
          if (id == last_id) {
            // If yes, query was `OK` and `shown_addresses` are replaced
            state['history'][id]['status']='OK';

            var data = JSON.decode(raw);

            // Calling `setState` will update the state and then repaint the component.
            //
            // In theory, state should be considered as immutable and `setState` or `replaceState` should be the only
            // way to change it.
            //
            // It is possible to do this when the whole state value is parsed from the server response
            // (the case of `shown_addresses`); however, it would be inefficient to copy the whole `history` just to
            // change one item. Therefore we mutate it and then replace it by itself.
            //
            // Have a look at `vacuum_persistent` package to achieve immutability of state.
            setState({
              'shown_addresses': data['results'],
              'history': state['history']
            });
          } else {
            // Otherwise, query was `canceled`
            state['history'][id]['status'] = 'canceled';

            setState({
              'history': state['history']
            });
          }
        })
        .catchError((Error error) {
          state['history'][id]['status'] = 'error';

          setState({
            'history': state['history']
          });
        });
  }

  /// Add a new [addressQuery] to the `state.history` Map with its status set to 'pending', then return its `id`.
  addQueryToHistory(String addressQuery) {
    var id = ++last_id;

    state['history'][id] = {
      'query': addressQuery,
      'status': 'pending'
    };

    setState({
      'history': state['history']
    });

    return id;
  }

  @override
  render() {
    return react.div({}, [
      react.h1({}, 'Geocode resolver'),
      geocodesResultList({
        // The state values are passed to the children as the properties.
        'data': state['shown_addresses']
      }),
      geocodesForm({
        // `newQuery` is the final callback of the button click.
        'submitter': newQuery
      }),
      geocodesHistoryList({
        'data': state['history'],
        // `newQuery` is the final callback of the button click.
        'reloader': newQuery
      })
    ]);
  }
}

var geocodesApp = react.registerComponent(() => new _GeocodesApp());

/// And finally, a few magic commands to wire it all up!
///
/// Select the root of the app and the place in the DOM where it should be mounted.
void main() {
  setClientConfiguration();
  react_dom.render(geocodesApp({}), querySelector('#content'));
}
