$(function() {
    'use strict';

    function render() {
        render_table(
            'pending',
            'Unassigned bugs (time critical components)',
            [
                {
                    label: 'ID',
                    className: 'id',
                    render: function(item) { return render_bug(item.id) }
                },
                {
                    label: 'Summary',
                    className: 'summary',
                    render: function(item) { return $.esc(item.summary) }
                },
                {
                    label: 'Comp',
                    className: 'component',
                    render: function(item) { return render_component(item.component) }
                },
                {
                    label: 'Created',
                    className: 'duration',
                    render: function(item) { return render_duration(item.creation_time_age) }
                },
                {
                    label: 'Commenter',
                    render: function(item) { return render_user(item.last_commenter) }
                },
                {
                    label: 'Commented',
                    className: 'duration',
                    render: function(item) { return render_duration(item.last_comment_time_age) }
                }
            ],
            function(data) {
                document.title = 'bteam dashboard (' + data.length + ')';
            }
        );
        render_table(
            'in_progress',
            'Assigned bugs being worked on (time critical components)',
            [
                {
                    label: 'ID',
                    className: 'id',
                    render: function(item) { return render_bug(item.id) }
                },
                {
                    label: 'Summary',
                    className: 'summary',
                    render: function(item) { return $.esc(item.summary) }
                },
                {
                    label: 'Owner',
                    render: function(item) { return render_user(item.assigned_to) }
                },
                {
                    label: 'Comp',
                    className: 'component',
                    render: function(item) { return render_component(item.component) }
                },
                {
                    label: 'Created',
                    className: 'duration',
                    render: function(item) { return render_duration(item.creation_time_age) }
                },
                {
                    label: 'Due',
                    className: 'duration',
                    render: function(item) { return render_duration(item.cf_due_date_age) }
                },
                {
                    label: 'Commented',
                    className: 'duration',
                    render: function(item) { return render_duration(item.last_comment_time_age) }
                }
            ]
        );
        render_table(
            'stalled',
            'Bugs waiting on more information (all components)',
            [
                {
                    label: 'ID',
                    className: 'id',
                    render: function(item) { return render_bug(item.id) }
                },
                {
                    label: 'Summary',
                    className: 'summary',
                    render: function(item) { return $.esc(item.summary) }
                },
                {
                    label: 'Owner',
                    render: function(item) { return render_user(item.assigned_to) }
                },
                {
                    label: 'Comp',
                    className: 'component',
                    render: function(item) { return render_component(item.component) }
                },
                {
                    label: 'Created',
                    className: 'duration',
                    render: function(item) { return render_duration(item.creation_time_age) }
                },
                {
                    label: 'NeedInfo From',
                    render: function(item) { return render_user(item.needinfo) }
                },
                {
                    label: 'Age',
                    className: 'duration',
                    render: function(item) { return render_duration(item.needinfo_time_age) }
                }
            ]
        );
        render_table(
            'in_dev',
            'Assigned bugs with patches (all components)',
            [
                {
                    label: 'ID',
                    className: 'id',
                    render: function(item) { return render_bug(item.id) }
                },
                {
                    label: 'Summary',
                    className: 'summary',
                    render: function(item) { return $.esc(item.summary) }
                },
                {
                    label: 'Owner',
                    render: function(item) { return render_user(item.assigned_to) }
                },
                {
                    label: 'Comp',
                    className: 'component',
                    render: function(item) { return render_component(item.component) }
                },
                {
                    label: 'Created',
                    className: 'duration',
                    render: function(item) { return render_duration(item.creation_time_age) }
                },
                {
                    label: 'Commented',
                    className: 'duration',
                    render: function(item) { return render_duration(item.last_comment_time_age) }
                }
            ]
        );
        render_table(
            'infra',
            'Infrastructure Bugs',
            [
                {
                    label: 'ID',
                    className: 'id',
                    render: function(item) { return render_bug(item.id) }
                },
                {
                    label: 'Summary',
                    className: 'summary',
                    render: function(item) { return $.esc(item.summary) }
                },
                {
                    label: 'Owner',
                    render: function(item) { return render_user(item.assigned_to) }
                },
                {
                    label: 'Created',
                    className: 'duration',
                    render: function(item) { return render_duration(item.creation_time_age) }
                },
                {
                    label: 'NeedInfo',
                    render: function(item) { return render_user(item.needinfo) }
                },
                {
                    label: 'Commented',
                    className: 'duration',
                    render: function(item) { return render_duration(item.last_comment_time_age) }
                }
            ]
        );
        $('#updated').text(new Date().toLocaleString());
    }

    function render_table(id, subtitle, fields, callback) {
        let $container = $('#' + id);
        if ($container.length == 0) {
            console.error('failed to find #' + id);
            return;
        }
        $container
            .empty()
            .append(
                $('<tr/>').append(
                    $('<td/>').addClass('loading').text('Loading...')
                )
            );
        $.getJSON('rpc/' + id, function(data) {
            if (data.error) {
                console.error(data.error);
                return;
            }

            let $table = $('#' + id);
            $table.empty();

            $table.append(
                $('<thead/>').append(
                    $('<tr/>').append(
                        $('<td/>')
                            .attr('colspan', fields.length)
                            .addClass('header')
                            .append($('<span/>').addClass('title').text(id.toUpperCase()))
                            .append($('<span/>').addClass('count').text('(' + data.length + ')'))
                            .append($('<span/>').addClass('subtitle').text(subtitle))
                    )
                )
            );

            let $tbody = $('<tbody/>');
            $table.append($tbody);

            let $tr = $('<tr/>').addClass('header');
            $.each(fields, function() {
                let field = this;
                $tr.append($('<th/>').addClass(field.className).text(field.label));
            });
            $tbody.append($tr);

            $.each(data, function() {
                let item = this;
                let $tr = $('<tr/>');
                $.each(fields, function() {
                    let field = this;
                    $tr.append($('<td/>').addClass(field.className).append(field.render(item)));
                });
                $tbody.append($tr);
            });

            if (data.length == 0) {
                $tbody
                    .append(
                        $('<tr/>').append(
                            $('<td/>')
                                .attr('colspan', fields.length)
                                .addClass('zarro')
                                .text('zarro boogs')
                        )
                    );
            }

            if (callback) {
                callback(data);
            }
        });
    }

    function render_bug(id) {
        return $('<a/>')
            .attr('href', 'https://bugzilla.mozilla.org/show_bug.cgi?id=' + id)
            .text(id);
    }

    function render_component(component) {
        switch (component) {
            case 'Custom Bug Entry Forms': return 'Bug Forms';
            case 'Extensions: Other': return component;
            default: return $.esc(component.replace('Extensions: ', ''));
        }
    }

    function render_user(user) {
        if (!user || user == 'nobody@mozilla.org') {
            return '-';
        }
        return $.esc(
            user.replace(/@mozilla\.(org|com)(\.uk)?$/, '')
                .replace(/@gmail\.com$/, '')
        );
    }

    function render_duration(ss) {
        if (!ss) {
            return '-';
        }
        let mm = Math.round(ss / 60),
            hh = Math.round(mm / 60),
            dd = Math.round(hh / 24),
            mo = Math.round(dd / 30),
            yy = Math.round(mo / 12);
        if (ss < 10) return 'just now';
        if (ss < 45) return ss + ' seconds ago';
        if (ss < 90) return 'a minute ago';
        if (mm < 45) return mm + ' minutes ago';
        if (mm < 90) return 'an hour ago';
        if (hh < 24) return hh + ' hours ago';
        if (hh < 36) return 'a day ago';
        if (dd < 30) return dd + ' days ago';
        if (dd < 45) return 'a month ago';
        if (mo < 12) return mo + ' months ago';
        if (mo < 18) return 'a year ago';
        return yy + ' years ago';
    }

    $.extend({
        esc: function(s) {
            return s === undefined
                ? ''
                : s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
        },
    });

    render();
    window.setInterval(render, 60 * 60 * 1000);
});
