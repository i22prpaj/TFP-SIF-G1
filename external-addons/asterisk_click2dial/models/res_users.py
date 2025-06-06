# Copyright 2010-2021 Akretion France (http://www.akretion.com/)
# @author: Alexis de Lattre <alexis.delattre@akretion.com>
# License AGPL-3.0 or later (http://www.gnu.org/licenses/agpl).

from odoo import _, api, fields, models
from odoo.exceptions import UserError, ValidationError


class ResUsers(models.Model):
    _inherit = "res.users"

    internal_number = fields.Char(copy=False, help="User's internal phone number.")
    dial_suffix = fields.Char(
        string="User-specific Dial Suffix",
        help="User-specific dial suffix such as aa=2wb for SCCP auto answer.",
    )
    callerid = fields.Char(
        string="Caller ID",
        copy=False,
        help="Caller ID used for the calls initiated by this user.",
    )
    # You'd probably think: Asterisk should reuse the callerID of sip.conf!
    # But it cannot, cf
    # http://lists.digium.com/pipermail/asterisk-users/
    # 2012-January/269787.html
    cdraccount = fields.Char(
        string="CDR Account",
        help="Call Detail Record (CDR) account used for billing this user.",
    )
    asterisk_chan_type = fields.Selection(
        [
            ("PJSIP", "PJSIP"),
            ("SIP", "SIP"),
            ("IAX2", "IAX2"),
            ("DAHDI", "DAHDI"),
            ("Zap", "Zap"),
            ("Skinny", "Skinny"),
            ("MGCP", "MGCP"),
            ("mISDN", "mISDN"),
            ("H323", "H323"),
            ("SCCP", "SCCP"),
            # Local works for click2dial, but it won't work in
            # _get_calling_number() when trying to identify the
            # channel of the user, so it's better not to propose it
            # ('Local', 'Local'),
        ],
        string="Asterisk Channel Type",
        default="PJSIP",
        help="Asterisk channel type, as used in the Asterisk dialplan. "
        "If the user has a regular IP phone, the channel type is probably 'PJSIP'.",
    )
    resource = fields.Char(
        string="Resource Name",
        copy=False,
        help="Resource name for the channel type selected. For example, "
        "if you use 'Dial(PJSIP/phone1)' in your Asterisk dialplan to ring "
        "the SIP phone of this user, then the resource name for this user "
        "is 'phone1'.  For a SIP phone, the phone number is often used as "
        "resource name, but not always.",
    )
    asterisk_chan_name = fields.Char(
        compute="_compute_asterisk_chan_name",
        store=True,
        string="Asterisk Channel Name",
    )
    alert_info = fields.Char(
        string="User-specific Alert-Info SIP Header",
        help="Set a user-specific Alert-Info header in SIP request to "
        "user's IP Phone for the click2dial feature. If empty, the "
        "Alert-Info header will not be added. You can use it to have a "
        "special ring tone for click2dial (a silent one !) or to "
        "activate auto-answer for example.",
    )
    variable = fields.Char(
        string="User-specific Variable",
        help="Set a user-specific 'Variable' field in the Asterisk "
        "Manager Interface 'originate' request for the click2dial "
        "feature. If you want to have several variable headers, separate "
        "them with '|'.",
    )
    asterisk_server_id = fields.Many2one(
        "asterisk.server",
        string="Asterisk Server",
        help="Asterisk server on which the user's phone is connected. "
        "If you leave this field empty, it will use the first Asterisk "
        "server of the user's company.",
    )

    @api.constrains("resource", "internal_number", "callerid")
    def _check_validity(self):
        for user in self:
            strings_to_check = [
                (_("Resource Name"), user.resource),
                (_("Internal Number"), user.internal_number),
                (_("Caller ID"), user.callerid),
            ]
            for check_string in strings_to_check:
                if check_string[1]:
                    try:
                        check_string[1].encode("ascii")
                    except UnicodeEncodeError:
                        raise ValidationError(
                            _(
                                f"The {check_string[0]} for the user {user.name} "
                                "should only have ASCII caracters"
                            )
                        ) from None

    @api.depends("asterisk_chan_type", "resource")
    def _compute_asterisk_chan_name(self):
        for user in self:
            chan_name = False
            if user.asterisk_chan_type and user.resource:
                chan_name = f"{user.asterisk_chan_type}/{user.resource}"
            user.asterisk_chan_name = chan_name

    def get_asterisk_server_from_user(self):
        """Returns an asterisk.server recordset"""
        self.ensure_one()
        # We check if the user has an Asterisk server configured
        if self.asterisk_server_id:
            ast_server = self.asterisk_server_id
        else:
            ast_server = self.env["asterisk.server"].search(
                [
                    "|",
                    ("company_id", "=", self.company_id.id),
                    ("company_id", "=", False),
                ],
                order="company_id",
                limit=1,
            )
            # If the user doesn't have an asterisk server,
            # we take the first one of the user's company
            if not ast_server:
                raise UserError(
                    _("No Asterisk server configured for the company '%s'.")
                    % self.company_id.display_name
                )
        return ast_server
