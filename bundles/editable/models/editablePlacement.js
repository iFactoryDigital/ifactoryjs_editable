
// import dependencies
const Model = require('model');

/**
 * create user class
 */
class EditablePlacement extends Model {
  /**
   * sanitises placement
   *
   * @return {Promise}
   */
  async sanitise(req) {
    // return placement
    return {
      id     : this.get('_id') ? this.get('_id').toString() : null,
      type   : this.get('type'),
      name   : this.get('name'),
      blocks : req ? (await Promise.all((this.get('blocks') || []).map(async (block) => {
        // import helpers
        const BlockHelper = helper('cms/block');

        // get from register
        const registered = BlockHelper.blocks().find(b => b.type === block.type) || BlockHelper.blocks().find(b => b.type === 'frontend.content');

        // check registered
        if (!registered) return null;

        // get data
        const data = {
          ...block,
          ...(await registered.render(req, block)),
        };

        // set uuid
        data.uuid = block.uuid;

        // return render
        return data;
      }))).filter(b => b) : null,
      position : this.get('position'),
    };
  }
}

/**
 * export user class
 * @type {user}
 */
module.exports = EditablePlacement;
