/** @odoo-module **/
"use strict"

import {patch} from "@web/core/utils/patch"
import {PhoneField} from "@web/views/fields/phone/phone_field"

patch(PhoneField.prototype, "asterisk_plus.PhoneField", {
    _onClickCallButton(e) {
        e.preventDefault()
        const {resModel, data} = this.props.record
        const args = [this.props.value, resModel, data.id]
        this.env.model.orm.call("asterisk_plus.server", "originate_call", args, {})
    }
})
