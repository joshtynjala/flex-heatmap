/*

Copyright (c) 2008 Esria, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/
package com.esria.controls
{
	import com.yahoo.astra.utils.NumberUtil;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;
	import mx.collections.IList;
	import mx.collections.ListCollectionView;
	import mx.collections.XMLListCollection;
	import mx.core.UIComponent;
	import mx.events.CollectionEvent;
	import mx.styles.CSSStyleDeclaration;
	import mx.styles.StyleManager;
		
	//----------------------------------
	//  Styles
	//----------------------------------

	/**
	 * The color values used by the default value of the <code>colorFunction</code>
	 * property. Each value in the Array is used in conjunction with the value
	 * at the same index in the <code>fillRatios</code> style to determine a
	 * region's color value.
	 */
	[Style(name="fillColors",type="Array")]

	/**
	 * The ratio values used by the default value of the <code>colorFunction</code>
	 * property. Each value in the Array is used in conjunction with the value
	 * at the same index in the <code>fillColors</code> style to determine a
	 * region's color value.
	 */
	[Style(name="fillRatios",type="Array")]

	/**
	 * A heatmap visualization component for Flex.
	 * 
	 * @see http://www.esria.com/ Built by Esria
	 * @see http://en.wikipedia.org/wiki/Heat_map Heat Map on Wikipedia
	 * @author Josh Tynjala
	 */
	public class HeatMap extends UIComponent
	{
		
	//----------------------------------
	//  Static Properties
	//----------------------------------

		/**
		 * @private
		 * A width cannot be determined from the data, so a default value has
		 * been chosen.
		 */
		private static const DEFAULT_MEASURED_WIDTH:Number = 250;

		/**
		 * @private
		 * A height cannot be determined from the data, so a default value has
		 * been chosen.
		 */
		private static const DEFAULT_MEASURED_HEIGHT:Number = 250;
		
	//----------------------------------
	//  Static Methods
	//----------------------------------
	
		/**
		 * @private
		 * Initializes the default style values.
		 */
		private static function initializeStyles():void
		{
			var styles:CSSStyleDeclaration = StyleManager.getStyleDeclaration("HeatMap");
			if(!styles)
			{
				styles = new CSSStyleDeclaration();
			}
			
			styles.defaultFactory = function():void
			{
				this.fillColors = [0x0000ff00, 0xaa00ff00, 0xccffff00, 0xeeff0000];
				this.fillRatios = [0, 0.34, 0.67, 1];
			}
			
			StyleManager.setStyleDeclaration("HeatMap", styles, false);
		}
		initializeStyles();

	//----------------------------------
	//  Constructor
	//----------------------------------
	
		/**
		 * Constructor.
		 */
		public function HeatMap()
		{
			super();
			this.mouseEnabled = false;
			this.dataProvider = new ArrayCollection();
		}
		
	//----------------------------------
	//  Properties
	//----------------------------------

		/**
		 * @private
		 * The colors are drawn to a transparent bitmap rather than to the
		 * graphics objects because bitmap drawing is faster.
		 */
		protected var bitmap:Bitmap;
	
		/**
		 * @private
		 * Flag indicating that the data caches need to be cleared because the
		 * data or the way it is parsed has changed. 
		 */
		protected var cachesNeedToBeCleared:Boolean = false;
		
		/**
		 * @private
		 * Storage for the dataProvider property.
		 */
		private var _dataProvider:ListCollectionView;
		
		[Bindable]
		/**
		 * The data to be displayed in the heatmap. Must be a ListCollectionView
		 * or a type that can be converted to a ListCollectionView such as an
		 * Array, XMLList, or IList.
		 */
		public function get dataProvider():Object
		{
			return this._dataProvider;
		}
		
		/**
		 * @private
		 */
		public function set dataProvider(value:Object):void
		{
			if(!value)
			{
				value = [];
			}
			
			if(this._dataProvider)
			{
				this._dataProvider.removeEventListener(CollectionEvent.COLLECTION_CHANGE, collectionChangeHandler);
			}
			
			if(value is Array)
			{
				this._dataProvider = new ArrayCollection(value as Array);
			}
			else if(value is ListCollectionView)
			{
				this._dataProvider = ListCollectionView(value);
			}
			else if(value is IList)
			{
				this._dataProvider = new ListCollectionView(IList(value));
			}
			else if(value is XMLList)
			{
				this._dataProvider = new XMLListCollection(value as XMLList);
			}
			else if(value is XML)
			{		
				var list:XMLList = new XMLList();		
				list += value;	
				this._dataProvider = new XMLListCollection(list);		
			}
			else
			{
				// convert it to an array containing this one item
				var array:Array = [];
				if(value != null)
				{
					array.push(value);
				}
				
				this._dataProvider = new ArrayCollection(array);
			}
			
			this._dataProvider.addEventListener(CollectionEvent.COLLECTION_CHANGE, collectionChangeHandler, false, 0, true);
			this.cachesNeedToBeCleared = true;
			this.invalidateDisplayList();
		}
		
		/**
		 * @private
		 * Storage for the horizontalField property.
		 */
		private var _horizontalField:String = "x";
		
		[Bindable]
		/**
		 * The field used to determine the horizontal position an item. The
		 * horizontal position is the absolute position of the item from the
		 * left edge of the component, in pixels.
		 * 
		 * <p>If the <code>horizontalFunction</code> is set, the <code>horizontalField</code>
		 * is ignored.</p>
		 * 
		 * @see #horizontalFunction
		 * @see #verticalField
		 * @see #verticalFunction
		 */
		public function get horizontalField():String
		{
			return this._horizontalField;
		}
		
		/**
		 * @private
		 */
		public function set horizontalField(value:String):void
		{
			this._horizontalField = value;
			this.cachesNeedToBeCleared = true;
			this.invalidateDisplayList();
		}
		
		/**
		 * @private
		 * Storage for the horizontalFunction property.
		 */
		private var _horizontalFunction:Function;
		
		[Bindable]
		/**
		 * A function used to determine the horizontal position an item. The
		 * horizontal position is the absolute position of the item from the
		 * left edge of the component, in pixels.
		 * 
		 * <p>The <code>horizontalFunction</code> takes precedence over the
		 * <code>horizontalField</code> when determining the horizontal
		 * position.</p>
		 * 
		 * <p>The horizontalFunction has the following signature:</p>
		 * <pre>function( item:Object ):Number</pre>
		 * <p>Where the <code>item</code> argument is an item from the heatmap's
		 * data provider, and the return value is the horizontal position of the
		 * item, in pixels.</p>
		 * 
		 * @see #horizontalField
		 * @see #verticalField
		 * @see #verticalFunction
		 */
		public function get horizontalFunction():Function
		{
			return this._horizontalFunction;
		}
		
		/**
		 * @private
		 */
		public function set horizontalFunction(value:Function):void
		{
			this._horizontalFunction = value;
			this.cachesNeedToBeCleared = true;
			this.invalidateDisplayList();
		}
		
		/**
		 * @private
		 * Storage for the verticalField property.
		 */
		private var _verticalField:String = "y";
		
		[Bindable]
		/**
		 * The field used to determine the vertical position an item. The
		 * vertical position is the absolute position of the item from the
		 * top edge of the component, in pixels.
		 * 
		 * <p>If the <code>verticalFunction</code> is set, the <code>verticalField</code>
		 * is ignored.</p>
		 * 
		 * @see #horizontalField
		 * @see #horizontalFunction
		 * @see #verticalFunction
		 */
		public function get verticalField():String
		{
			return this._verticalField;
		}
		
		/**
		 * @private
		 */
		public function set verticalField(value:String):void
		{
			this._verticalField = value;
			this.cachesNeedToBeCleared = true;
			this.invalidateDisplayList();
		}
		
		/**
		 * @private
		 * Storage for the verticalFunction property.
		 */
		private var _verticalFunction:Function;
		
		[Bindable]
		/**
		 * A function used to determine the vertical position an item. The
		 * vertical position is the absolute position of the item from the
		 * top edge of the component, in pixels.
		 * 
		 * <p>The <code>verticalFunction</code> takes precedence over the
		 * <code>verticalField</code> when determining the vertical
		 * position.</p>
		 * 
		 * <p>The verticalFunction has the following signature:</p>
		 * <pre>function( item:Object ):Number</pre>
		 * <p>Where the <code>item</code> argument is an item from the heatmap's
		 * data provider, and the return value is the vertical position of the
		 * item, in pixels.</p>
		 * 
		 * @see #horizontalField
		 * @see #horizontalFunction
		 * @see #verticalField
		 */
		public function get verticalFunction():Function
		{
			return this._verticalFunction;
		}
		
		/**
		 * @private
		 */
		public function set verticalFunction(value:Function):void
		{
			this._verticalFunction = value;
			this.cachesNeedToBeCleared = true;
			this.invalidateDisplayList();
		}
		
		/**
		 * @private
		 * Storage for the weightField property.
		 */
		private var _weightField:String;
		
		[Bindable]
		/**
		 * The field used to determine the weight of an item. The weight of
		 * items is used to calculate the color of a heatmap region in which an
		 * item appears. By default, the weight of every item in the heatmap is
		 * <code>1</code>. The <code>weightField</code> property may be used to
		 * give items differing weight values.
		 * 
		 * @see #weightFunction
		 * @see #colorFunction 
		 */
		public function get weightField():String
		{
			return this._weightField;
		}
		
		/**
		 * @private
		 */
		public function set weightField(value:String):void
		{
			this._weightField = value;
			this.cachesNeedToBeCleared = true;
			this.invalidateDisplayList();
		}
		
		/**
		 * @private
		 * Storage for the weightFunction property.
		 */
		private var _weightFunction:Function;
		
		[Bindable]
		/**
		 * A function used to determine the weight of an item. The weight of
		 * items is used to calculate the color of a heatmap region in which an
		 * item appears. By default, the weight of every item in the heatmap is
		 * <code>1</code>. The <code>weightField</code> property may be used to
		 * give items differing weight values.
		 * 
		 * <p>The weightFunction has the following signature:</p>
		 * <pre>function( item:Object ):Number</pre>
		 * <p>Where the <code>item</code> argument is an item from the heatmap's
		 * data provider, and the return value is a Number representing the
		 * "weight" or value of an item used to determine the color of a region.</p>
		 * 
		 * @see #weightField
		 * @see #colorFunction 
		 */
		public function get weightFunction():Function
		{
			return this._weightFunction;
		}
		
		/**
		 * @private
		 */
		public function set weightFunction(value:Function):void
		{
			this._weightFunction = value;
			this.cachesNeedToBeCleared = true;
			this.invalidateDisplayList();
		}
		
		/**
		 * @private
		 */
		private var _colorFunction:Function = calculateRegionColor;
		
		/**
		 * A function used to determine the color of a region. The default
		 * colorFunction uses the <code>fillColors</code> and <code>fillRatios</code>
		 * styles to calculate the colors.
		 * 
		 * <p>The color function has the following signature:</p>
		 * <pre>function( value:Number ):uint</pre>
		 * 
		 * <p>Where the <code>value</code> argument is on a scale between zero
		 * and one that represents a comparison between the different region
		 * weight values.</p>
		 */
		public function get colorFunction():Function
		{
			return this._colorFunction;
		}
		
		/**
		 * @private
		 */
		public function set colorFunction(value:Function):void
		{
			this._colorFunction = value;
			this.invalidateDisplayList();
		}
		
		/**
		 * @private
		 * Storage for the regionSize property.
		 */
		private var _regionSize:Number = 10;
		
		/**
		 * The size of the edge of a region, in pixels. Each region drawn on the
		 * heatmap will be n by n pixels.
		 */
		public function get regionSize():Number
		{
			return this._regionSize;
		}
		
		/**
		 * @private
		 */
		public function set regionSize(value:Number):void
		{
			this._regionSize = value;
			this.cachesNeedToBeCleared = true;
			this.invalidateDisplayList();
		}
		
		/**
		 * @private
		 * Storage for the sampleSize property.
		 */
		private var _sampleSize:int = 1;
		
		/**
		 * Used to display only a subset of the data. If this value is greater
		 * than <code>1</code>, the heatmap will use every nth item in the data
		 * provider rather than every single item.
		 */
		public function get sampleSize():int
		{
			return this._sampleSize;
		}
		
		/**
		 * @private
		 */
		public function set sampleSize(value:int):void
		{
			this._sampleSize = value;
			this.cachesNeedToBeCleared = true;
			this.invalidateDisplayList();
		}

		/**
		 * @private
		 * Used to cache the calculated position values so that they don't
		 * need to be recalculated every time <code>itemToPosition()</code> is
		 * called. Performance optimization.
		 */
		private var _cachedPositions:Dictionary = new Dictionary(true);

		/**
		 * @private
		 * Used to cache the calculated region indices so that they don't
		 * need to be recalculated every time <code>itemToRegionIndex()</code>
		 * is called. Performance optimization.
		 */
		private var _cachedRegionIndices:Dictionary = new Dictionary(true);
		
		/**
		 * @private
		 * Used to cache the calculated item weight values so that they don't
		 * need to be recalculated every time <code>itemToWeight()</code>
		 * is called. Performance optimization.
		 */
		private var _cachedWeights:Dictionary = new Dictionary(true);

		/**
		 * @private
		 * Caches the value of the unscaledWidth property so that it can be
		 * accessed as a variable rather than a property. Performance
		 * optimization.
		 */
		private var _savedUnscaledWidth:Number;
		
		/**
		 * @private
		 * Caches the value of the unscaledHeight property so that it can be
		 * accessed as a variable rather than a property. Performance
		 * optimization.
		 */
		private var _savedUnscaledHeight:Number;
		
	//----------------------------------
	//  Public Methods
	//----------------------------------
		
		/**
		 * Determines the position of an item on a heatmap. Value is based on
		 * the <code>horizontalField</code>, <code>horizontalFunction</code>,
		 * <code>verticalField</code>, and <code>verticalFunction</code> properties.
		 * 
		 * @param item		An item from the data provider
		 * @return			The x and y position of the item, in pixels
		 */
		public function itemToPosition(item:Object):Point
		{
			if(!item)
			{
				return new Point(NaN, NaN);
			}
			
			var cachedPos:Point = this._cachedPositions[item];
			if(cachedPos)
			{
				return cachedPos;
			}
			
			var x:Number = NaN;
			if(this._horizontalFunction != null)
			{
				x = this._horizontalFunction(item);
			}
			else
			{
				//I would use hasOwnProperty() here, but for massive data sets,
				//it's signifcantly faster to use try/catch instead.
				try
				{
					x = item[this._horizontalField]
				}
				catch(error:Error)
				{
				}
			}
			
			var y:Number = NaN;
			if(this._verticalFunction != null)
			{
				y = this._verticalFunction(item);
			}
			else
			{
				try
				{
					y = item[this._verticalField];
				}
				catch(error:Error)
				{
					//way faster than hasOwnProperty() for valid data
				}
			}
			
			var position:Point = new Point(x, y);
			this._cachedPositions[item] = position;
			return position;
		}
		
		/**
		 * Calculates the weight of an item based on the <code>weightField</code>
		 * and <code>weightFunction</code> properties.
		 * 
		 * @param item		A item from the data provider
		 * @return			The item's weight value
		 */
		public function itemToWeight(item:Object):Number
		{
			if(!item)
			{
				return 0;
			}
			
			var cachedWeight:Object = this._cachedWeights[item];
			if(cachedWeight is Number)
			{
				return cachedWeight as Number;
			}
			
			var weight:Number = 1;
			if(this._weightFunction != null)
			{
				weight = this._weightFunction(item);
			}
			else if(this._weightField != null)
			{
				try
				{
					weight = item[this._weightField];
				}
				catch(error:Error)
				{
					//by default, no field is specified.
					//if a field is specified, but it doesn't exist on the item,
					//then we can't assume that the user wants to default to 1
					//like we can if no field is specified at all.
					weight = 0;
				}
			}
			
			this._cachedWeights[item] = weight;
			return weight; //default is 1 if the valueFunction and valueField aren't defined
		}
		
	//----------------------------------
	//  Protected Methods
	//----------------------------------

		/**
		 * @private
		 */
		override protected function createChildren():void
		{
			super.createChildren();
			
			if(!this.bitmap)
			{
				this.bitmap = new Bitmap();
				this.addChild(this.bitmap);
			}
		}

		/**
		 * @private
		 */
		override protected function measure():void
		{
			super.measure();
			this.measuredWidth = DEFAULT_MEASURED_WIDTH;
			this.measuredHeight = DEFAULT_MEASURED_HEIGHT;
		}

		/**
		 * @private
		 */
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth, unscaledHeight);
			
			var newUnscaledWidth:Number =  NumberUtil.roundUpToNearest(unscaledWidth, this._regionSize);
			var newUnscaledHeight:Number = NumberUtil.roundUpToNearest(unscaledHeight, this._regionSize);
			
			var dimensionsChanged:Boolean = this._savedUnscaledWidth != newUnscaledWidth || this._savedUnscaledHeight != newUnscaledHeight;
			
			if(this.cachesNeedToBeCleared)
			{
				this._cachedPositions = new Dictionary(true);
			}
			
			if(this.cachesNeedToBeCleared || dimensionsChanged)
			{
				this._cachedRegionIndices = new Dictionary(true);
				this._cachedWeights = new Dictionary(true);
			}
			
			//we're saving these values in member variables because it's faster
			//than calling the getters for unscaledWidth and unscaledHeight.
			this._savedUnscaledWidth = newUnscaledWidth;
			this._savedUnscaledHeight = newUnscaledHeight;
			
			if(this.bitmap.bitmapData)
			{
				this.bitmap.bitmapData.dispose();
				this.bitmap.bitmapData = null;
			}
			
			if(unscaledWidth > 0 && unscaledHeight > 0)
			{
				var values:Array = this.calculateRegionWeights();
				this.bitmap.bitmapData = new BitmapData(unscaledWidth, unscaledHeight, true);
				this.drawRegionsAsBitmap(values);
			}
			
			this.cachesNeedToBeCleared = false;
		}
		
		/**
		 * @private
		 * Determines the weight value for each region so that the region colors
		 * may be determined.
		 */
		protected function calculateRegionWeights():Array
		{
			//I prefer to work with raw Arrays. That's why the expected dataProvider is a ListCollectionView (easy conversion)
			var data:Array = this._dataProvider.list.toArray().concat();
			
			//we have to filter the data if we're sampling it, rather than using the full set
			if(this.sampleSize > 1)
			{
				data = data.filter(function(item:Object, index:int, source:Array):Boolean
				{
					return index % this._sampleSize == 0;
				}, this);
			}
			
			//we sort by region index to improve performance
			data.sort(compareItemRegions);
			
			var values:Array = [];
			var dataCount:int = data.length;
			var currentIndex:int = 0;
			for(var i:Number = 0; i < unscaledHeight; i += this._regionSize)
			{
				for(var j:Number = 0; j < unscaledWidth; j += this._regionSize)
				{ 
					var bounds:Rectangle = new Rectangle(j, i, this._regionSize, this._regionSize);
					var value:Number = 0;
					for(var k:int = currentIndex; k < dataCount; k++)
					{
						var item:Object = data[k];
						var itemPosition:Point = this.itemToPosition(item);
						if(!bounds.containsPoint(itemPosition))
						{
							//this is all the points we can use
							break;
						}
						value += this.itemToWeight(item);
						currentIndex++;
					}
					values.push(value);
				} 
			}
			
			return values;
		}
		
		/**
		 * @private
		 * Draws the regions on the heatmap using the graphics object.
		 */
		protected function drawRegions(values:Array):void
		{
			var maxValue:Number = Math.max.apply(null, values);
			var minValue:Number = Math.min.apply(null, values);
			var range:Number = maxValue - minValue;
			
			var g:Graphics = this.graphics;
			g.clear();
			
			var realUnscaledWidth:Number = this.unscaledWidth;
			var realUnscaledHeight:Number = this.unscaledHeight;
			
			var index:int = 0;
			for(var i:Number = 0; i < this._savedUnscaledHeight; i += this._regionSize)
			{
				for(var j:Number = 0; j < this._savedUnscaledWidth; j += this._regionSize)
				{
					var value:Number = values[index];
					if(isNaN(value))
					{
						//we need this in case there are no values at this index at all (undefined)
						value = 0;
					}
					var w:Number = ((j + this._regionSize) <= realUnscaledWidth) ? this._regionSize : (realUnscaledWidth - j);
					var h:Number = ((i + this._regionSize) <= realUnscaledHeight) ? this._regionSize : (realUnscaledHeight - i);
					
					var color:uint = this._colorFunction((value - minValue) / range);
					var alpha:Number = ((color >> 24) & 0xff) / 0xff;
					
					g.beginFill(color, alpha);
					g.drawRect(j, i, w, h);
					g.endFill();
					
					index++;
				}
			}
		}
		
		/**
		 * @private
		 * Draws the regions on the heatmap using a bitmap.
		 */
		private function drawRegionsAsBitmap(values:Array):void
		{
			var maxValue:Number = Math.max.apply(null, values);
			var minValue:Number = Math.min.apply(null, values);
			var range:Number = maxValue - minValue;
			
			var realUnscaledWidth:Number = this.unscaledWidth;
			var realUnscaledHeight:Number = this.unscaledHeight;
			
			var bmpData:BitmapData = this.bitmap.bitmapData;
			bmpData.lock();
			
			//reusing the same bitmap is faster
			var fillRect:Rectangle = new Rectangle();
			
			var index:int = 0;
			for(var i:Number = 0; i < this._savedUnscaledHeight; i += this._regionSize)
			{
				for(var j:Number = 0; j < this._savedUnscaledWidth; j += this._regionSize)
				{
					var value:Number = values[index];
					if(isNaN(value))
					{
						//we need this in case there are no values at this index at all (undefined)
						value = 0;
					}
					var w:Number = ((j + this._regionSize) <= realUnscaledWidth) ? this._regionSize : (realUnscaledWidth - j);
					var h:Number = ((i + this._regionSize) <= realUnscaledHeight) ? this._regionSize : (realUnscaledHeight - i);
					
					var color:uint = this._colorFunction((value - minValue) / range);
					
					fillRect.x = j;
					fillRect.y = i;
					fillRect.width = w;
					fillRect.height = h;
					bmpData.fillRect(fillRect, color);
					
					index++;
				}
			}
			
			bmpData.unlock();
		}
		
		/**
		 * @private
		 * Determines which region in which an item appears.
		 * 
		 * @param item		An item from the data provider
		 */
		protected function itemToRegionIndex(item:Object):int
		{
			var cachedRegion:Object = this._cachedRegionIndices[item];
			if(cachedRegion is int)
			{
				return cachedRegion as int;
			}
			
			var position:Point = this.itemToPosition(item);
			if(position.x >= this._savedUnscaledWidth || position.y >= this._savedUnscaledHeight)
			{
				//outside of bounds, so not in a region
				return this._cachedRegionIndices[item] = -1;
			}
			
			var columnCount:int = Math.ceil(this._savedUnscaledWidth / this._regionSize);
			var colIndex:int = position.x / this._regionSize;
			var rowIndex:int = position.y / this._regionSize;
			
			var region:int = columnCount * rowIndex + colIndex;
			this._cachedRegionIndices[item] = region;
			return region;
		}
		
		/**
		 * @private
		 * Comparison function used for sorting the items in the data provider
		 * based on the region of the heatmap in which they appear.
		 * 
		 * @param item1		The first item to compare
		 * @param item2		The second item to compare
		 */
		protected function compareItemRegions(item1:Object, item2:Object):int
		{
			var region1:int = this.itemToRegionIndex(item1);
			var region2:int = this.itemToRegionIndex(item2);
			
			//check for items outside the drawing area, put them at the end where they won't be used
			if(region1 == -1)
			{
				if(region2 == -1)
				{
					return 0;
				}
				return 1;
			}
			/*if(region1 == -1 && region2 == -1) return 0;
			if(region1 == -1) return 1;*/
			if(region2 == -1) return -1;
			
			if(region1 > region2) return 1;
			if(region1 < region2) return -1;
			return 0;
		}
		
		/**
		 * @private
		 * If the collection changes, the component needs to redraw.
		 */
		protected function collectionChangeHandler(event:CollectionEvent):void
		{
			this.cachesNeedToBeCleared = true;
			this.invalidateDisplayList();
		}
		
		/**
		 * @private
		 * The default region color calculation function.
		 */
		private function calculateRegionColor(value:Number):uint
		{
			var colors:Array = this.getStyle("fillColors");
			var ratios:Array = this.getStyle("fillRatios");
			while(ratios.length < colors.length)
			{
				ratios.push(1);
			}
			
			var secondRatioIndex:int = ratios.length - 1;
			var colorCount:int = colors.length;
			for(var i:int = 0; i < colorCount; i++)
			{
				var currentRatio:Number = ratios[i];
				if(currentRatio >= value)
				{
					secondRatioIndex = i;
					break;
				}
			}
			
			if(secondRatioIndex == 0)
			{
				return colors[0];
			}
			var color1:uint = colors[secondRatioIndex - 1];
			var color2:uint = colors[secondRatioIndex];
			var ratio1:Number = ratios[secondRatioIndex - 1];
			var ratio2:Number = ratios[secondRatioIndex];
			var subRatio:Number = 1 - (value - ratio1) / (ratio2 - ratio1);
			return this.blendColors(color1, color2, subRatio);
		}
		
		/**
		 * @private
		 * Blends two colors together by a specified ratio.
		 */
		private function blendColors(color1:uint, color2:uint, ratio:Number = 0.5):uint
		{
			var remaining:Number = 1 - ratio;
			
			var alpha1:uint = (color1 >> 24) & 0xff;
			var red1:uint = (color1 >> 16) & 0xff;
			var green1:uint = (color1 >> 8) & 0xff;
			var blue1:uint = color1 & 0xff;
			
			var alpha2:uint = (color2 >> 24) & 0xff;
			var red2:uint = (color2 >> 16) & 0xff;
			var green2:uint = (color2 >> 8) & 0xff;
			var blue2:uint = color2 & 0xff;
			 
			color1 = ((alpha1 * ratio) << 24) + ((red1 * ratio) << 16) + ((green1 * ratio) << 8) + (blue1 * ratio);
			color2 = ((alpha2 * remaining) << 24) + ((red2 * remaining) << 16) + ((green2 * remaining) << 8) + (blue2 * remaining);

			return color1 + color2;

		}

	}
}