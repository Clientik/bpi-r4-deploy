'use strict';
'require view';
'require fs';
'require ui';
'require uci';

function runCheck() {
	return fs.exec('/usr/sbin/fw-update', ['check', '--json']).then(function (r) {
		try { return JSON.parse((r && r.stdout) || '{}'); } catch (e) { return {}; }
	}).catch(function () { return {}; });
}

return view.extend({
	load: function () {
		return Promise.all([ uci.load('fwupdate'), runCheck() ]);
	},

	render: function (data) {
		var d = data[1] || {};
		var self = this;

		var statusCell = d.update
			? E('strong', { style: 'color:#b00' }, _('Update available'))
			: E('span', { style: 'color:#080' }, _('Up to date'));
		if (!d.tag) statusCell = E('span', { style: 'color:#a60' }, _('Could not reach GitHub'));

		var install = E('button', {
			'class': 'btn cbi-button-action',
			'disabled': d.update ? null : 'disabled',
			'click': ui.createHandlerFn(self, function () {
				if (!confirm(_('Download and flash %s from %s?\nSettings are kept; the router will reboot.').format(d.asset || '', d.tag || '')))
					return;
				ui.showModal(_('Updating firmware'), [
					E('p', { 'class': 'spinning' }, _('Downloading and flashing… the router will reboot. Reconnect in a minute.'))
				]);
				return fs.exec('/usr/sbin/fw-update', ['install']).catch(function () {});
			})
		}, _('Download & install update'));

		var recheck = E('button', {
			'class': 'btn cbi-button-reload',
			'click': ui.createHandlerFn(self, function () { return runCheck().then(function () { location.reload(); }); })
		}, _('Check again'));

		return E('div', {}, [
			E('h2', {}, _('Firmware Update')),
			E('div', { 'class': 'cbi-section-descr' },
				_('Checks this fork\'s GitHub releases for a newer image for your exact variant and installs it (keeps settings). Independent of the official Attended Sysupgrade.')),
			E('div', { 'class': 'table' }, [
				E('div', { 'class': 'tr' }, [ E('div', { 'class': 'td left', style: 'width:33%' }, _('Repository')), E('div', { 'class': 'td left' }, d.repo || '-') ]),
				E('div', { 'class': 'tr' }, [ E('div', { 'class': 'td left' }, _('Variant')), E('div', { 'class': 'td left' }, (d.tag || '-') + (d.asset ? ('  (' + d.asset + ')') : '')) ]),
				E('div', { 'class': 'tr' }, [ E('div', { 'class': 'td left' }, _('Installed build')), E('div', { 'class': 'td left' }, (d.current || '-') + (d.commit && d.commit != 'unknown' ? ('  (' + d.commit + ')') : '')) ]),
				E('div', { 'class': 'tr' }, [ E('div', { 'class': 'td left' }, _('Latest release')), E('div', { 'class': 'td left' }, d.latest || '-') ]),
				E('div', { 'class': 'tr' }, [ E('div', { 'class': 'td left' }, _('Status')), E('div', { 'class': 'td left' }, statusCell) ])
			]),
			E('div', { style: 'margin-top:1em' }, [ install, ' ', recheck ]),
			E('p', { style: 'margin-top:1em;color:#888' },
				_('CLI: fw-update check | fw-update list | fw-update install [tag] | fw-update install --dry-run'))
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
