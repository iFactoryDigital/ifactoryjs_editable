<eden-editable>
  <div ref="editable" class="eden-editable grid-stack" if={ this.show }>

    <div each={ el, i in this.placement.get('blocks') || [] } class="grid-stack-item" data-gs-x={ el._grid.x || '0' } data-gs-y={ el._grid.y || '0' } data-gs-width={ el._grid.w || 1 } data-gs-height={ el._grid.h || 1 }>
      <div class="grid-stack-item-content">
        <div editing={ getThis().editing } preview={ getThis().preview } el={ el } class={ el.class } data-is={ getElement(el) } data-block={ el.uuid } data={ el } block={ el } on-editing={ onSetEditing } on-save={ onSaveBlock } on-remove={ onRemoveBlock } on-refresh={ onRefreshBlock } placement={ i } i={ i } />
      </div>
    </div>

    <div class="grid-stack-item grid-stack-item-add" data-gs-x={ placement.get('add._grid.x') || '0' } data-gs-y={ placement.get('add._grid.y') || '0' } data-gs-width={ placement.get('add._grid.w') || '4' } data-gs-height={ placement.get('add._grid.h') || '2' }>
      <div class="grid-stack-item-content">
        <button ref="on-add" class="grid-add" onclick={ onAddPress }>
          Add Widget
        </button>
      </div>
    </div>
  </div>
  <editable-sidebar ref="sidebar" blocks={ opts.blocks } add-block={ onAddBlock } />

  <script>
    // do mixins
    this.mixin('acl');
    this.mixin('model');
    this.mixin('loading');

    // require uuid
    const uuid = require('uuid');

    // set values
    this.show      = true;
    this.placement = opts.placement ? (opts.model ? this.parent.placement : this.model('placement', opts.placement)) : this.model('placement', {
      'position' : opts.position
    });

    /**
     * safely gets this
     */
    getThis () {
      // return this
      return this;
    }

    /**
     * get element
     *
     * @param  {Object} child
     *
     * @return {*}
     */
    getElement (child) {
      // return get child
      return (child || {}).tag ? 'block-' + (child || {}).tag : 'eden-loading';
    }

    /**
     * on add block
     *
     * @param  {Event} e
     *
     * @return {*}
     */
    onAddPress (e) {
      // prevent
      e.preventDefault();
      e.stopPropagation();
      
      // open modal
      this.refs.sidebar.show();
    }

    /**
     * adds block by type
     *
     * @param  {String} type
     *
     * @return {*}
     */
    async onAddBlock (type) {
      // get uuid
      const dotProp = require('dot-prop-immutable');

      // lowest rightest
      const lowestRightest = (this.placement.get('blocks') || []).reduce((accum, block) => {
        // get bottommost
        const right = parseInt(block._grid.x) + parseInt(block._grid.w);
        const bottom = parseInt(block._grid.h) + parseInt(block._grid.y);

        const aRight = (parseInt(accum._grid.x) + parseInt(accum._grid.w));
        const aBottom = (parseInt(accum._grid.h) + parseInt(accum._grid.y));

        // lower bottom
        if (bottom > aBottom) {
          // return
          return block;
        } else if (bottom === aBottom && right > aRight) {
          // return block
          return block;
        }

        // return accumulated
        return accum;
      }, {
        _grid : this.placement.get('add._grid') || {
          w : 4,
          h : 2,
          x : 0,
          y : 0
        }
      });

      // bottom
      const right = lowestRightest._grid.x + lowestRightest._grid.w;
      const bottom = lowestRightest._grid.y + lowestRightest._grid.h;

      // create block
      let block = {
        'uuid' : uuid(),
        'type' : type,
        '_grid' : this.placement.get('add._grid') || {
          w : 4,
          h : 2,
          x : 0,
          y : 0
        },
      };

      // set new add placement
      this.placement.set('add._grid', {
        w : 4,
        h : 2,
        x : (right >= 12 ? 0 : right),
        y : (right >= 12 ? bottom : bottom),
      });

      // check positions
      if (!this.placement.get('blocks')) this.placement.set('blocks', []);
      
      // push block
      this.placement.get('blocks').push(block);

      // save placement
      await this.onSaveBlock(block);
    }

    /**
     * on refresh block
     *
     * @param  {Event}  e
     * @param  {Object} block
     */
    async onSaveBlock (block, preventUpdate) {
      // clone
      const blockClone = Object.assign({}, block);

      // prevent update check
      if (!preventUpdate) {
        // set loading
        block.saving = true;

        // update view
        this.updateGrid();
      }
      
      // delete editing
      delete block.saving;
      delete blockClone.saving;

      // log data
      const res = await fetch('/editable/placement/' + this.placement.get('id') + '/block/save', {
        'body' : JSON.stringify({
          'block' : blockClone
        }),
        'method'  : 'post',
        'headers' : {
          'Content-Type' : 'application/json'
        },
        'credentials' : 'same-origin'
      });

      // load data
      const result = await res.json();

      // set logic
      for (let key in result.result) {
        // clone to placement
        block[key] = result.result[key];
      }

      // save placement
      await this.savePlacement(preventUpdate);

      // check prevent update
      if (!preventUpdate) {
        // set loading
        delete blockClone.saving;

        // update view
        this.updateGrid();
      }
    }

    /**
     * saves placement
     *
     * @param {Boolean} preventRefresh
     *
     * @return {Promise}
     */
    async savePlacement (preventRefresh) {
      // set loading
      this.loading('save', true);

      // check type
      if (!this.placement.type) this.placement.set('position', opts.position);

      // log data
      let res = await fetch('/editable/placement/' + (this.placement.get('id') ? this.placement.get('id') + '/update' : 'create'), {
        'body'    : JSON.stringify(this.placement.get()),
        'method'  : 'post',
        'headers' : {
          'Content-Type' : 'application/json'
        },
        'credentials' : 'same-origin'
      });

      // load data
      let data = await res.json();

      // set logic
      for (let key in data.result) {
        // clone to placement
        this.placement.set(key, data.result[key]);

        // set in opts
        if (data.result[key] && !opts.model) opts.placement[key] = data.result[key];
      }

      // on save
      if (opts.onSave) opts.onSave(this.placement);

      // set loading
      this.loading('save', false);

      // update view
      this.updateGrid();
    }

    /**
     * init dragula
     */
    initGrid () {
      // check required
      if (!this.required) {
        // set required
        this.required = true;

        // require ui
        require('jquery-ui/ui/data');
        require('jquery-ui/ui/version');
        require('jquery-ui/ui/plugin');
        require('jquery-ui/ui/scroll-parent');
        require('jquery-ui/ui/safe-active-element');
        require('jquery-ui/ui/disable-selection');
        require('jquery-ui/ui/widget');
        require('jquery-ui/ui/widgets/mouse');
        require('jquery-ui/ui/widgets/resizable');
        require('jquery-ui/ui/widgets/draggable');

        // require gridstack
        require('gridstack/dist/gridstack');

        // require local
        require('editable/public/js/jquery-ui');
      }
      
      // gridstack
      jQuery(this.refs.editable).gridstack({}).on('change', (e) => {
        // data-gs-x="0" data-gs-y="1" data-gs-width="12" data-gs-height="4"
        // commit to items
        jQuery('.grid-stack-item', this.refs.editable).each((i, item) => {
          // child
          const child = jQuery(item);
          const data = child.data();

          // get block
          const block = this.placement.get('blocks').find(b => b.uuid === jQuery('[data-block]', item).attr('data-block'));
          
          // check block
          if (child.is('.grid-stack-item-add')) {
            // set add grid
            this.placement.set('add', {
              _grid : {
                x : data.gsX,
                y : data.gsY,
                h : data.gsHeight,
                w : data.gsWidth,
              }
            });
          } else {
            // set grid
            block._grid = {
              x : data.gsX,
              y : data.gsY,
              h : data.gsHeight,
              w : data.gsWidth,
            };
          }
        });

        // save
        this.savePlacement();
      });

      // data
      this.grid = jQuery(this.refs.editable).data('gridstack');
    }

    /**
     * updates grid
     */
    updateGrid() {
      // remove grid
      this.grid.destroy();

      // update
      this.show = false;
      this.update();
      this.show = true;
      this.update();

      // init grid
      this.initGrid();
    }

    /**
     * on update
     *
     * @type {update}
     */
    this.on('update', () => {
      // check frontend
      if (!this.eden.frontend) return;

      // set preview
      this.preview = !this.acl.validate(opts.acl || 'admin');
    });

    /**
     * on mount
     *
     * @type {mount}
     */
    this.on('mount', () => {
      // check frontend
      if (!this.eden.frontend) return;

      // set preview
      this.preview = !this.acl.validate(opts.acl || 'admin');

      // set placement
      this.placement = opts.placement ? (opts.model ? this.parent.placement : this.model('placement', opts.placement)) : this.model('placement', {
        'position' : opts.position
      });

      // init dragula
      if (!this.grid && this.acl.validate(opts.acl || 'admin')) this.initGrid();
    });
  </script>
</eden-editable>
