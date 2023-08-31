//
//  TitleSubtitleRow.swift
//  
//
//  Created by Noah Martin on 8/31/23.
//

import Foundation
import SwiftUI

struct TitleSubtitleRow: View {
  let title: String
  let subtitle: String

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(title)
          .font(.headline)
          .foregroundStyle(Color(UIColor.label))
          .padding(.leading, 8)

        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(Color(UIColor.secondaryLabel))
          .padding(.leading, 8)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .foregroundColor(Color(UIColor.secondaryLabel))
        .padding(.trailing, 8)
    }
  }
}