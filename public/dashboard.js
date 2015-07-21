YUI().use(['datasource', 'datatable', 'datatable-sort'], function(Y) {
  function init_table(id, caption, sort_by, columns, callback) {
    var ds = new Y.DataSource.IO({
      source: 'http://glob.uno/bteam/rpc/' + id
    });
    ds.plug(Y.Plugin.DataSourceJSONSchema, {
      schema: {
        resultListLocator: '',
        resultFields: columns
      }
    });
    var container = document.createElement('div');
    container.id = id;
    document.body.appendChild(container);
    var table = new Y.DataTable({
      caption: '<div class="table_title">' + id.replace('_', ' ') + '</div>' +
               '<div class="table_caption">' + Y.Escape.html(caption) + '</div>',
      columns: columns,
      sortBy: sort_by
    });
    table.set('strings.emptyMessage', 'Zarro Boogs Found');
    table.plug(Y.Plugin.DataTableDataSource, {
      datasource: ds
    });
    table.render('#' + id).showMessage('loadingMessage');
    table.datasource.load();
    if (callback) {
        ds.after('response', callback);
    }
    return table;
  }

  var format_bug = '<a href="https://bugzilla.mozilla.org/show_bug.cgi?id={value}">{value}</a>';

  function format_component(o) {
    switch (o.value) {
      case 'Administration': return 'admin';
      case 'Custom Bug Entry Forms': return 'form';
      case 'Extensions: MozProjectReview': return 'kickoff';
      case 'Infrastructure': return 'infra';
      default: return '?';
    }
  }

  function format_user(o) {
    if (!o.value || o.value == 'nobody@mozilla.org')
      return '-';
    return o.value
      .replace(/@mozilla\.(org|com)(\.uk)?$/, '')
      .replace(/@gmail\.com$/, '');
  }

  function format_duration(o) {
    return o.value ? timeAgo(o.value) : '-';
  }

  init_table(
    'pending',
    'Unassigned bugs',
    { last_comment_time_age: 'desc'},
    [
      {
        key: 'id',
        parse: 'number',
        label: 'ID',
        sortable: true,
        allowHTML: true,
        className: 'id',
        formatter: format_bug
      },
      {
        key: 'summary',
        label: 'Summary',
        className: 'summary'
      },
      {
        key: 'component',
        sortable: true,
        label: 'Comp',
        formatter: format_component
      },
      {
        key: 'creation_time_age',
        parse: 'number',
        label: 'Created',
        sortable: true,
        className: 'duration',
        formatter: format_duration
      },
      {
        key: 'last_commenter',
        label: 'Commenter',
        sortable: true,
        formatter: format_user
      },
      {
        key: 'last_comment_time_age',
        parse: 'number',
        label: 'Commented',
        sortable: true,
        className: 'duration',
        formatter: format_duration
      }
    ],
    function(a) {
        if (a.response.results.length > 0) {
            document.title += ' (' + a.response.results.length + ')';
        }
    }
  );

  init_table(
    'in_progress',
    'Assigned bugs being worked on',
    { last_comment_time_age: 'desc' },
    [
      {
        key: 'id',
        parse: 'number',
        label: 'ID',
        sortable: true,
        allowHTML: true,
        className: 'id',
        formatter: format_bug
      },
      {
        key: 'summary',
        label: 'Summary',
        className: 'summary'
      },
      {
        key: 'assigned_to',
        label: 'Owner',
        sortable: true,
        formatter: format_user
      },
      {
        key: 'component',
        sortable: true,
        label: 'Comp',
        formatter: format_component
      },
      {
        key: 'creation_time_age',
        parse: 'number',
        label: 'Created',
        sortable: true,
        className: 'duration',
        formatter: format_duration
      },
      {
        key: 'cf_due_date_age',
        parse: 'number',
        label: 'Due',
        sortable: true,
        className: 'duration',
        formatter: format_duration
      },
      {
        key: 'last_comment_time_age',
        parse: 'number',
        label: 'Commented',
        sortable: true,
        className: 'duration',
        formatter: format_duration
      }
    ]
  );

  init_table(
    'stalled',
    'Bugs waiting on more information',
    { needinfo_time_age: 'desc' },
    [
      {
        key: 'id',
        parse: 'number',
        label: 'ID',
        sortable: true,
        allowHTML: true,
        className: 'id',
        formatter: format_bug
      },
      {
        key: 'summary',
        label: 'Summary',
        className: 'summary'
      },
      {
        key: 'assigned_to',
        label: 'Owner',
        sortable: true,
        formatter: format_user
      },
      {
        key: 'component',
        sortable: true,
        label: 'Comp',
        formatter: format_component
      },
      {
        key: 'creation_time_age',
        parse: 'number',
        label: 'Created',
        sortable: true,
        className: 'duration',
        formatter: format_duration
      },
      {
        key: 'needinfo',
        label: 'NeedInfo From',
        sortable: true,
        formatter: format_user
      },
      {
        key: 'needinfo_time_age',
        parse: 'number',
        label: 'Age',
        sortable: true,
        className: 'duration',
        formatter: format_duration
      }
    ]
  );

  init_table(
    'infra',
    'Infrastructure Bugs',
    { creation_time_age: 'desc' },
    [
      {
        key: 'id',
        parse: 'number',
        label: 'ID',
        sortable: true,
        allowHTML: true,
        className: 'id',
        formatter: format_bug
      },
      {
        key: 'summary',
        label: 'Summary',
        className: 'summary'
      },
      {
        key: 'assigned_to',
        label: 'Owner',
        sortable: true,
        formatter: format_user
      },
      {
        key: 'creation_time_age',
        parse: 'number',
        label: 'Created',
        sortable: true,
        className: 'duration',
        formatter: format_duration
      },
      {
        key: 'needinfo',
        label: 'NeedInfo',
        sortable: false,
        formatter: format_user
      },
      {
        key: 'last_comment_time_age',
        parse: 'number',
        label: 'Commented',
        sortable: true,
        className: 'duration',
        formatter: format_duration
      }
    ]
  );

  window.setInterval(function() { location.reload(); }, 1000 * 60 * 60);
  document.getElementById('updated').innerHTML = new Date().toLocaleString();
});

function timeAgo(param) {
  var ss = param.constructor === Date ? Math.round((new Date() - param) / 1000) : param;
  var mm = Math.round(ss / 60),
      hh = Math.round(mm / 60),
      dd = Math.round(hh / 24),
      mo = Math.round(dd / 30),
      yy = Math.round(mo / 12);
  if (ss < 10) return 'just now';
  if (ss < 45) return ss + ' seconds';
  if (ss < 90) return 'a minute';
  if (mm < 45) return mm + ' minutes';
  if (mm < 90) return 'an hour';
  if (hh < 24) return hh + ' hours';
  if (hh < 36) return 'a day';
  if (dd < 30) return dd + ' days';
  if (dd < 45) return 'a month';
  if (mo < 12) return mo + ' months';
  if (mo < 18) return 'a year';
  return yy + ' years';
}
