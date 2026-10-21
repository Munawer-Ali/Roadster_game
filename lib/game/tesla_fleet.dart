import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'car_builder.dart';

final _colors = [
  vm.Vector4(0.9, 0.9, 0.92, 1),
  vm.Vector4(0.03, 0.03, 0.035, 1),
  vm.Vector4(0.62, 0.02, 0.03, 1),
  vm.Vector4(0.04, 0.14, 0.45, 1),
  vm.Vector4(0.28, 0.29, 0.31, 1),
  vm.Vector4(0.62, 0.63, 0.65, 1),
];

class TeslaModel {
  TeslaModel(this.name, this.length, this.width, this.height, this._geometry, {this.fixedPaint});

  final String name;
  final double length;
  final double width;
  final double height;
  final MeshGeometry _geometry;
  final PhysicallyBasedMaterial? fixedPaint;
  final Map<int, Mesh> _meshes = {};

  static int get colorCount => _colors.length;

  Mesh mesh(int color) {
    final key = fixedPaint == null ? color % _colors.length : 0;
    return _meshes.putIfAbsent(
      key,
      () => Mesh(_geometry, fixedPaint ?? paint(_colors[key], metallic: 0.35, roughness: 0.28)),
    );
  }

  static Future<TeslaModel> load(String name, {PhysicallyBasedMaterial? fixedPaint}) async {
    final data = await rootBundle.load('assets/fleet/$name.bin');
    final buffer = data.buffer;
    final start = data.offsetInBytes;
    final length = data.getFloat32(0, Endian.little);
    final width = data.getFloat32(4, Endian.little);
    final height = data.getFloat32(8, Endian.little);
    final vertices = data.getUint32(12, Endian.little);
    final indexCount = data.getUint32(16, Endian.little);
    var offset = 20;
    Float32List floats(int count) {
      final list = Float32List.fromList(buffer.asFloat32List(start + offset, count));
      offset += count * 4;
      return list;
    }

    final positions = floats(vertices * 3);
    final normals = floats(vertices * 3);
    final colors = floats(vertices * 4);
    final indices = Uint32List.fromList(buffer.asUint32List(start + offset, indexCount));
    final geometry = MeshGeometry.fromArrays(positions: positions, normals: normals, colors: colors, indices: indices);
    return TeslaModel(name, length, width, height, geometry, fixedPaint: fixedPaint);
  }
}

class TeslaFleet {
  TeslaFleet(this.models);

  final List<TeslaModel> models;

  static Future<TeslaFleet> load() async {
    final steel = paint(vm.Vector4(0.62, 0.63, 0.65, 1), metallic: 1, roughness: 0.38);
    return TeslaFleet([
      await TeslaModel.load('model_3'),
      await TeslaModel.load('model_s'),
      await TeslaModel.load('model_y'),
      await TeslaModel.load('model_x'),
      await TeslaModel.load('cybertruck', fixedPaint: steel),
    ]);
  }
}
