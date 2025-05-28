import json
import logging
from odoo import models, fields, api, tools, release, release
from odoo.exceptions import ValidationError, UserError
from .settings import debug

logger = logging.getLogger(__name__)


class ResUser(models.Model):
    _inherit = 'res.groups'

    @api.constrains('users')
    def _manage_pbx_users(self):
        if self.env.context.get('install_mode'):
            return
        server = self.env.ref('asterisk_plus.default_server').sudo()
        if not server.auto_create_pbx_users:
            debug(self, 'Auto create PBX users not enabled.')
            return
        if not (self.env.user.has_group('base.group_erp_manager') or
                self.env.user.has_group('base.group_system')):
            logger.warning('Skippung PBX users auto create.')
            return
        pbx_users = self.env['asterisk_plus.user'].sudo().search([]).mapped('user')
        pbx_group = self.env.ref('asterisk_plus.group_asterisk_user')
        for rec in self:
            if rec.id != pbx_group.id:
                # Not a PBX user group.
                continue
            new_users = rec.users - pbx_users
            # Create new users
            self.env['asterisk_plus.user'].sudo().auto_create(new_users)
            remove_pbx_users = pbx_users - rec.users
            for user in remove_pbx_users:
                pbx_user = self.env['asterisk_plus.user'].sudo().search([('user', '=', user.id)])
                pbx_user.channels.unlink()
                pbx_user.unlink()
