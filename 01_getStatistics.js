// get area by territory 
// dhemerson.costa@ipam.org.br

// an adaptation from:
// calculate area of @author João Siqueira

// definir tamanho do buffer (em metros)
var buffer_size = [100, 200, 500];

// carregar pontos
var sites = ee.FeatureCollection('users/dh-conciani/yuri/sites2');


// define root imageCollection
var root = 'projects/mapbiomas-workspace/public/collection7/';

// define files to process 
var asset = [
   root + 'mapbiomas_collection70_integration_v2'
  ];

//////////////////////////////////////////////////////////
// loop devera começar aqui 
buffer_size.forEach(function(size_i) {
  // calcular buffer
  var buffers = sites.map(function(i) {
    return(i.buffer(size_i));
  });
  
  var empty = ee.Image().byte();
  var buffer = empty.paint({
    'featureCollection': buffers,
    'color': 'ID',
      }).rename('territory');
    
  
  // define classification regions 
  var territory = buffer;
  
  // plot regions
  Map.addLayer(territory.randomVisualizer(), {}, 'buffer ' + size_i);
  
  // change the scale if you need.
  var scale = 30;
  
  // define the years to bem computed 
  var years = ee.List.sequence({'start': 2020, 'end': 2021, 'step': 1}).getInfo();
  
  // define a Google Drive output folder 
  var driverFolder = 'YURI-EXPORT';
  
  // for each file 
  asset.map(function(file) {
    // get the classification for the file[i] 
    var asset_i = ee.Image(file).selfMask();
    // set only the basename
    var basename = file.slice(ee.String(root).length().getInfo());
    
    // Image area in hectares
    var pixelArea = ee.Image.pixelArea().divide(10000);
    
    // Geometry to export
    var geometry = asset_i.geometry();
    
    // convert a complex object to a simple feature collection 
    var convert2table = function (obj) {
      obj = ee.Dictionary(obj);
        var territory = obj.get('territory');
        var classesAndAreas = ee.List(obj.get('groups'));
        
        var tableRows = classesAndAreas.map(
            function (classAndArea) {
                classAndArea = ee.Dictionary(classAndArea);
                var classId = classAndArea.get('class');
                var area = classAndArea.get('sum');
                var tableColumns = ee.Feature(null)
                    .set('territory', territory)
                    .set('class_id', classId)
                    .set('area', area)
                    .set('buffer_size', size_i);
                    
                return tableColumns;
            }
        );
    
        return ee.FeatureCollection(ee.List(tableRows));
    };
    
    // compute the area
    var calculateArea = function (image, territory, geometry) {
        var territotiesData = pixelArea.addBands(territory).addBands(image)
            .reduceRegion({
                reducer: ee.Reducer.sum().group(1, 'class').group(1, 'territory'),
                geometry: geometry,
                scale: scale,
                maxPixels: 1e12
            });
            
        territotiesData = ee.List(territotiesData.get('groups'));
        var areas = territotiesData.map(convert2table);
        areas = ee.FeatureCollection(areas).flatten();
        return areas;
    };
    
    // perform per year 
    var areas = years.map(
        function (year) {
            var image = asset_i.select('classification_' + year);
            var areas = calculateArea(image, territory, geometry);
            // set additional properties
            areas = areas.map(
                function (feature) {
                    return feature.set('year', year);
                }
            );
            return areas;
        }
    );
    
    areas = ee.FeatureCollection(areas).flatten();
    
    Export.table.toDrive({
        collection: areas,
        description: 'buffer_size_' + size_i,
        folder: driverFolder,
        fileFormat: 'CSV'

    });
  });
});

