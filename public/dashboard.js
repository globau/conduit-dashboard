YUI().use(['datasource', 'datatable', 'datatable-sort'], function(Y) {
  function init_table(id, columns) {
    var ds = new Y.DataSource.IO({
      source: 'http://glob.uno/bteam/rpc/' + id
    });
    ds.plug(Y.Plugin.DataSourceJSONSchema, {
      schema: {
        resultListLocator: '',
        resultFields: columns
      }
    });
    var table = new Y.DataTable({
      caption: id.toUpperCase(),
      columns: columns,
      sortBy: { state_date_age: 'desc' }
    });
    table.plug(Y.Plugin.DataTableDataSource, {
      datasource: ds
    });
    table.render('#' + id).showMessage('loadingMessage');
    table.datasource.load();
    return table;
  }

  init_table('unanswered', [
    {
      key: 'id',
      parse: 'number',
      label: 'ID',
      sortable: true,
      allowHTML: true,
      className: 'id',
      formatter: '<a href="https://bugzilla.mozilla.org/show_bug.cgi?id={value}">{value}</a>'
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
      formatter: function(o) {
        return o.value.replace(/^([^@]+)@.+$/, '$1');
      }
    },
    {
      key: 'component',
      sortable: true,
      label: 'Comp',
      formatter: function(o) {
        return o.value == 'Administration' ? 'admin' : 'form';
      }
    },
    {
      key: 'creation_time_age',
      parse: 'number',
      label: 'Age',
      sortable: true,
      className: 'age',
      formatter: function(o) {
        return moment.duration(o.value, 'seconds').humanize();
      }
    },
    {
      key: 'state_date_age',
      parse: 'number',
      label: 'State',
      sortable: true,
      className: 'age',
      formatter: function(o) {
        return moment.duration(o.value, 'seconds').humanize();
      }
    }
  ]);

  init_table('pending', [
    {
      key: 'id',
      parse: 'number',
      label: 'ID',
      sortable: true,
      allowHTML: true,
      className: 'id',
      formatter: '<a href="https://bugzilla.mozilla.org/show_bug.cgi?id={value}">{value}</a>'
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
      formatter: function(o) {
        return o.value.replace(/^([^@]+)@.+$/, '$1');
      }
    },
    {
      key: 'component',
      sortable: true,
      label: 'Comp',
      formatter: function(o) {
        return o.value == 'Administration' ? 'admin' : 'form';
      }
    },
    {
      key: 'creation_time_age',
      parse: 'number',
      label: 'Age',
      sortable: true,
      className: 'age',
      formatter: function(o) {
        return moment.duration(o.value, 'seconds').humanize();
      }
    },
    {
      key: 'state_date_age',
      parse: 'number',
      label: 'State',
      sortable: true,
      className: 'age',
      title: 'Time since last comment',
      formatter: function(o) {
        return moment.duration(o.value, 'seconds').humanize();
      }
    },
    {
      key: 'cf_due_date_age',
      parse: 'number',
      label: 'Due',
      sortable: true,
      className: 'age',
      formatter: function(o) {
        return o.value ? moment.duration(o.value, 'seconds').humanize() : '-';
      }
    }
  ]);

  init_table('needinfo', [
    {
      key: 'id',
      parse: 'number',
      label: 'ID',
      sortable: true,
      allowHTML: true,
      className: 'id',
      formatter: '<a href="https://bugzilla.mozilla.org/show_bug.cgi?id={value}">{value}</a>'
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
      formatter: function(o) {
        return o.value.replace(/^([^@]+)@.+$/, '$1');
      }
    },
    {
      key: 'needinfo',
      label: 'NeedInfo',
      sortable: true
    },
    {
      key: 'component',
      sortable: true,
      label: 'Comp',
      formatter: function(o) {
        return o.value == 'Administration' ? 'admin' : 'form';
      }
    },
    {
      key: 'creation_time_age',
      parse: 'number',
      label: 'Age',
      sortable: true,
      className: 'age',
      formatter: function(o) {
        return moment.duration(o.value, 'seconds').humanize();
      }
    },
    {
      key: 'state_date_age',
      parse: 'number',
      label: 'State',
      sortable: true,
      className: 'age',
      title: 'Time since last comment',
      formatter: function(o) {
        return moment.duration(o.value, 'seconds').humanize();
      }
    }
  ]);

  /* debugging
  init_table('all', [
    {
      key: 'id',
      parse: 'number',
      label: 'ID',
      sortable: true,
      allowHTML: true,
      className: 'id',
      formatter: '<a href="https://bugzilla.mozilla.org/show_bug.cgi?id={value}">{value}</a>'
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
      formatter: function(o) {
        return o.value.replace(/^([^@]+)@.+$/, '$1');
      }
    },
    {
      key: 'component',
      sortable: true,
      label: 'Comp',
      formatter: function(o) {
        return o.value == 'Administration' ? 'admin' : 'form';
      }
    },
    {
      key: 'state_date_age',
      parse: 'number',
      label: 'Age',
      sortable: true,
      className: 'age',
      formatter: function(o) {
        return moment.duration(o.value, 'seconds').humanize();
      }
    }
  ]);
  */
});
