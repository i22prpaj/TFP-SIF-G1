# -*- coding: utf-8 -*

from datetime import datetime, timedelta
import json
import logging
from odoo import models, fields, api
from odoo.exceptions import ValidationError

logger = logging.getLogger(__name__)


class CallEvent(models.Model):
    _name = 'asterisk_plus.call_event'
    _description = 'Call Event'
    _order = 'id'
    _rec_name = 'id'

    call = fields.Many2one('asterisk_plus.call', ondelete='cascade', required=True)
    event = fields.Char(required=True)
