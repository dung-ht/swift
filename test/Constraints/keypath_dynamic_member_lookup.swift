// RUN: %target-swift-frontend -emit-sil -verify %s | %FileCheck %s

struct Point {
  let x: Int
  var y: Int
}

struct Rectangle {
  var topLeft, bottomRight: Point
}

@dynamicMemberLookup
struct Lens<T> {
  var obj: T

  init(_ obj: T) {
    self.obj = obj
  }

  subscript<U>(dynamicMember member: KeyPath<T, U>) -> Lens<U> {
    get { return Lens<U>(obj[keyPath: member]) }
  }

  subscript<U>(dynamicMember member: WritableKeyPath<T, U>) -> Lens<U> {
    get { return Lens<U>(obj[keyPath: member]) }
    set { obj[keyPath: member] = newValue.obj }
  }

  // Used to make sure that keypath and string based lookup are
  // property disambiguated.
  subscript(dynamicMember member: String) -> Lens<Int> {
    return Lens<Int>(42)
  }
}

var topLeft = Point(x: 0, y: 0)
var bottomRight = Point(x: 10, y: 10)

var lens = Lens(Rectangle(topLeft: topLeft,
                          bottomRight: bottomRight))

// CHECK: function_ref @$s29keypath_dynamic_member_lookup4LensV0B6MemberACyqd__Gs15WritableKeyPathCyxqd__G_tcluig
// CHECK-NEXT: apply %45<Rectangle, Point>({{.*}})
// CHECK: function_ref @$s29keypath_dynamic_member_lookup4LensV0B6MemberACyqd__Gs7KeyPathCyxqd__G_tcluig
// CHECK-NEXT: apply %54<Point, Int>({{.*}})
_ = lens.topLeft.x

// CHECK: function_ref @$s29keypath_dynamic_member_lookup4LensV0B6MemberACyqd__Gs15WritableKeyPathCyxqd__G_tcluig
// CHECK-NEXT: apply %69<Rectangle, Point>({{.*}})
// CHECK: function_ref @$s29keypath_dynamic_member_lookup4LensV0B6MemberACyqd__Gs15WritableKeyPathCyxqd__G_tcluig
// CHECK-NEXT: apply %76<Point, Int>({{.*}})
_ = lens.topLeft.y

lens.topLeft = Lens(Point(x: 1, y: 2)) // Ok
lens.bottomRight.y = Lens(12)          // Ok

@dynamicMemberLookup
class A<T> {
  var value: T

  init(_ v: T) {
    self.value = v
  }

  subscript<U>(dynamicMember member: KeyPath<T, U>) -> U {
    get { return value[keyPath: member] }
  }
}

// Let's make sure that keypath dynamic member lookup
// works with inheritance

class B<T> : A<T> {}

func bar(_ b: B<Point>) {
  let _: Int = b.x
  let _ = b.y
}

struct Point3D {
  var x, y, z: Int
}

// Make sure that explicitly declared members take precedence
class C<T> : A<T> {
  var x: Float = 42
}

func baz(_ c: C<Point3D>) {
  // CHECK: ref_element_addr {{.*}} : $C<Point3D>, #C.x
  let _ = c.x
  // CHECK: [[Y:%.*]] = keypath $KeyPath<Point3D, Int>, (root $Point3D; stored_property #Point3D.z : $Int)
  // CHECK: [[KEYPATH:%.*]] = function_ref @$s29keypath_dynamic_member_lookup1AC0B6Memberqd__s7KeyPathCyxqd__G_tcluig
  // CHECK-NEXT: apply [[KEYPATH]]<Point3D, Int>({{.*}}, [[Y]], {{.*}})
  let _ = c.z
}

@dynamicMemberLookup
struct SubscriptLens<T> {
  var value: T

  subscript(foo: String) -> Int {
    get { return 42 }
  }

  subscript<U>(dynamicMember member: KeyPath<T, U>) -> U {
    get { return value[keyPath: member] }
  }

  subscript<U>(dynamicMember member: WritableKeyPath<T, U>) -> U {
    get { return value[keyPath: member] }
    set { value[keyPath: member] = newValue }
  }
}

func keypath_with_subscripts(_ arr: SubscriptLens<[Int]>,
                             _ dict: inout SubscriptLens<[String: Int]>) {
  // CHECK: keypath $WritableKeyPath<Array<Int>, ArraySlice<Int>>, (root $Array<Int>; settable_property $ArraySlice<Int>,  id @$sSays10ArraySliceVyxGSnySiGcig : {{.*}})
  _ = arr[0..<3]
  // CHECK: keypath $KeyPath<Array<Int>, Int>, (root $Array<Int>; gettable_property $Int,  id @$sSa5countSivg : {{.*}})
  for idx in 0..<arr.count {
    // CHECK: keypath $WritableKeyPath<Array<Int>, Int>, (root $Array<Int>; settable_property $Int,  id @$sSayxSicig : {{.*}})
    let _ = arr[idx]
    // CHECK: keypath $WritableKeyPath<Array<Int>, Int>, (root $Array<Int>; settable_property $Int,  id @$sSayxSicig : {{.*}})
    print(arr[idx])
  }

  // CHECK: function_ref @$s29keypath_dynamic_member_lookup13SubscriptLensVySiSScig
  _ = arr["hello"]
  // CHECK: function_ref @$s29keypath_dynamic_member_lookup13SubscriptLensVySiSScig
  _ = dict["hello"]

  if let index = dict.value.firstIndex(where: { $0.value == 42 }) {
    // CHECK: keypath $KeyPath<Dictionary<String, Int>, (key: String, value: Int)>, (root $Dictionary<String, Int>; gettable_property $(key: String, value: Int),  id @$sSDyx3key_q_5valuetSD5IndexVyxq__Gcig : {{.*}})
    let _ = dict[index]
  }
  // CHECK: keypath $WritableKeyPath<Dictionary<String, Int>, Optional<Int>>, (root $Dictionary<String, Int>; settable_property $Optional<Int>,  id @$sSDyq_Sgxcig : {{.*}})
  dict["ultimate question"] = 42
}
