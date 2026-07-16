'use strict';
'require view';
'require fs';
'require ui';
'require uci';
'require poll';

function callJson(args) {
	return fs.exec('/usr/sbin/fw-update', args).then(function (r) {
		try { return JSON.parse((r && r.stdout) || '{}'); } catch (e) { return {}; }
	}).catch(function () { return {}; });
}

function fmtMB(b) { return (b / 1048576).toFixed(1); }

return view.extend({
	load: function () {
		return Promise.all([ uci.load('fwupdate'), callJson(['check', '--json']) ]);
	},

	startInstall: function (d) {
		var self = this;
		if (!confirm(_('Download and flash %s from %s?\nSettings are kept; the router will reboot.').format(d.asset || '', d.tag || '')))
			return;

		var body = E('div', {}, [
			E('p', { 'id': 'fwup-phase', 'class': 'spinning' }, _('Starting…')),
			E('div', { style: 'background:#ddd;border-radius:3px;height:14px;overflow:hidden' }, [
				E('div', { 'id': 'fwup-bar', style: 'background:#5bc0de;height:14px;width:0%' })
			]),
			E('p', { 'id': 'fwup-detail', style: 'margin-top:.5em;color:#888' }, '')
		]);
		ui.showModal(_('Updating firmware'), [ body ]);

		fs.exec('/usr/sbin/fw-update', ['install', '--background']).then(function () {
			poll.add(function () {
				return callJson(['status', '--json']).then(function (s) {
					var ph = document.getElementById('fwup-phase'),
					    bar = document.getElementById('fwup-bar'),
					    det = document.getElementById('fwup-detail');
					if (!ph) { poll.stop(); return; }
					if (s.phase === 'resolving') {
						ph.textContent = _('Contacting GitHub… (15 s connect timeout)');
					} else if (s.phase === 'downloading') {
						var pct = (s.total > 0) ? Math.min(100, Math.round(s.done * 100 / s.total)) : 0;
						ph.textContent = _('Downloading update…');
						bar.style.width = pct + '%';
						det.textContent = fmtMB(s.done) + ' / ' + (s.total > 0 ? fmtMB(s.total) : '?') + ' MB  (' + pct + '%)';
					} else if (s.phase === 'flashing') {
						ph.textContent = _('Flashing… the router will reboot. Reconnect in a minute.');
						bar.style.width = '100%';
						det.textContent = '';
						poll.stop();
					} else if (s.phase === 'error') {
						ph.textContent = _('Failed: ') + (s.msg || _('unknown error'));
						ph.className = '';
						ph.style.color = '#b00';
						poll.stop();
						ui.hideModal();
						ui.addNotification(null, E('p', {}, _('Firmware update failed: ') + (s.msg || '')), 'error');
					}
				});
			}, 2);
		});
	},

	render: function (data) {
		var d = data[1] || {};
		var self = this;

		var statusCell = d.update
			? E('strong', { style: 'color:#b00' }, _('Update available'))
			: E('span', { style: 'color:#080' }, _('Up to date'));
		if (!d.tag) statusCell = E('span', { style: 'color:#a60' }, _('Could not reach GitHub (blocked/offline?)'));

		var install = E('button', {
			'class': 'btn cbi-button-action',
			'disabled': d.update ? null : 'disabled',
			'click': ui.createHandlerFn(self, function () { return self.startInstall(d); })
		}, _('Download & install update'));

		var recheck = E('button', {
			'class': 'btn cbi-button-reload',
			'click': ui.createHandlerFn(self, function () { location.reload(); })
		}, _('Check again'));

		return E('div', {}, [
			E('h2', {}, _('Firmware Update')),
			E('div', { 'class': 'cbi-section-descr' },
				_('Checks this fork\'s GitHub releases for a newer image for your exact variant and installs it (keeps settings). Independent of the official Attended Sysupgrade.')),
			E('div', { 'class': 'table' }, [
				E('div', { 'class': 'tr' }, [ E('div', { 'class': 'td left', style: 'width:33%' }, _('Repository')), E('div', { 'class': 'td left' }, d.repo || '-') ]),
				E('div', { 'class': 'tr' }, [ E('div', { 'class': 'td left' }, _('Variant')), E('div', { 'class': 'td left' }, (d.tag || '-') + (d.asset ? ('  (' + d.asset + ')') : '')) ]),
				E('div', { 'class': 'tr' }, [ E('div', { 'class': 'td left' }, _('Installed build')), E('div', { 'class': 'td left' }, (d.current || '-') + (d.commit && d.commit != 'unknown' ? ('  (' + d.commit + ')') : '')) ]),
				E('div', { 'class': 'tr' }, [ E('div', { 'class': 'td left' }, _('Latest release')), E('div', { 'class': 'td left' }, (d.latest || '-') + (d.latest_commit && d.latest_commit != 'unknown' ? ('  (' + String(d.latest_commit).substring(0, 9) + ')') : '')) ]),
				E('div', { 'class': 'tr' }, [ E('div', { 'class': 'td left' }, _('Status')), E('div', { 'class': 'td left' }, statusCell) ])
			]),
			E('div', { style: 'margin-top:1em' }, [ install, ' ', recheck ]),
			E('p', { style: 'margin-top:1em;color:#888' },
				_('CLI: fw-update check | list | install [--dry-run] [tag] | status'))
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
