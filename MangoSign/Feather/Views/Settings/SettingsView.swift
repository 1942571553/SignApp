//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

// MARK: - View
struct SettingsView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	@State private var _currentIcon: String? = UIApplication.shared.alternateIconName
	@StateObject private var _brand = BrandStore.shared
	@State private var _configURL: String = ""
	@State private var _isSyncing = false
	
	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>
	
	private var selectedCertificate: CertificatePair? {
		guard
			_storedSelectedCert >= 0,
			_storedSelectedCert < _certificates.count
		else {
			return nil
		}
		return _certificates[_storedSelectedCert]
	}

    
	private let _sourceUrl = "https://github.com/1942571553/SignApp"
    
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Settings")) {
			Form {
				_brandHeader()

				_server()

				_feedback()
                
				Section {
					NavigationLink(destination: AppearanceView()) {
						Label(.localized("Appearance"), systemImage: "paintbrush")
					}
					NavigationLink(destination: AppIconView(currentIcon: $_currentIcon)) {
						Label(.localized("App Icon"), systemImage: "app.badge")
					}
				}
                
				NBSection(.localized("Certificates")) {
                    
					if let cert = selectedCertificate {
						CertificatesCellView(cert: cert)
					} else {
						Text(.localized("No Certificate"))
							.font(.footnote)
							.foregroundColor(.disabled())
					}
					NavigationLink(destination: CertificatesView()) {
						Label(.localized("Certificates"), systemImage: "checkmark.seal")
					}
                 
				} footer: {
					Text(.localized("Add and manage certificates used for signing applications."))
				}
                
				NBSection(.localized("Features")) {
					NavigationLink(destination: ConfigurationView()) {
						Label(.localized("Signing Options"), systemImage: "signature")
					}
					NavigationLink(destination: ArchiveView()) {
						Label(.localized("Archive & Compression"), systemImage: "archivebox")
					}
					NavigationLink(destination: InstallationView()) {
						Label(.localized("Installation"), systemImage: "arrow.down.circle")
					}
				} footer: {
					Text(.localized("Configure the apps way of installing, its zip compression levels, and custom modifications to apps."))
				}
                
				_directories()
                
				Section {
					NavigationLink(destination: ResetView()) {
						Label(.localized("Reset"), systemImage: "trash")
					}
				} footer: {
					Text(.localized("Reset the applications sources, certificates, apps, and general contents."))
				}
			}
			.onAppear {
				_configURL = _brand.configURL
			}
		}
	}
}

// MARK: - View extension
extension SettingsView {
	@ViewBuilder
	private func _brandHeader() -> some View {
		Section {
			HStack(spacing: 12) {
				FRAppIconView(size: 44)
				VStack(alignment: .leading, spacing: 2) {
					Text(_brand.displayName)
						.font(.headline)
					if let subtitle = _brand.brand?.subtitle, !subtitle.isEmpty {
						Text(subtitle)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
			}
			.padding(.vertical, 4)
		}
	}

	@ViewBuilder
	private func _server() -> some View {
		Section {
			TextField("https://你的域名/api/config?token=", text: $_configURL)
				.keyboardType(.URL)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.font(.footnote)

			Button {
				_brand.configURL = _configURL
				_isSyncing = true
				Task {
					await _brand.refresh()
					_isSyncing = false
				}
			} label: {
				HStack {
					Text(.localized("同步远程配置"))
					Spacer()
					if _isSyncing {
						ProgressView()
					}
				}
			}
			.disabled(_isSyncing)

			if let error = _brand.lastError {
				Text(error)
					.font(.caption)
					.foregroundStyle(.red)
			} else if let date = _brand.lastSync {
				Text(.localized("上次同步：%@", arguments: date.formatted(date: .abbreviated, time: .shortened)))
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		} header: {
			Text(.localized("服务器"))
		} footer: {
			Text(.localized("填写签名站品牌配置接口地址，App 启动时自动拉取名称、公告、主题色和客服链接。"))
		}
	}

	@ViewBuilder
	private func _feedback() -> some View {
		Section {
			NavigationLink(destination: AboutView()) {
				Label {
					Text(verbatim: .localized("About %@", arguments: Bundle.main.name))
				} icon: {
					FRAppIconView(size: 23)
				}
			}
            
			if let url = _brand.supportURL {
				Button(.localized("联系客服"), systemImage: "safari") {
					UIApplication.shared.open(url)
				}
			}
			Button(.localized("开源声明"), systemImage: "chevron.left.forwardslash.chevron.right") {
				UIApplication.open(URL(string: _sourceUrl)!)
			}
		} footer: {
			Text(.localized("本 App 基于开源项目 Feather（GPL-3.0）二次开发，源码与修改说明见上方链接。"))
		}
	}
    
	@ViewBuilder
	private func _directories() -> some View {
		NBSection(.localized("Misc")) {
			Button(.localized("Open Documents"), systemImage: "folder") {
				UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Archives"), systemImage: "folder") {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Certificates"), systemImage: "folder") {
				UIApplication.open(FileManager.default.certificates.toSharedDocumentsURL()!)
			}
		} footer: {
			Text(.localized("All of the apps files are contained in the documents directory, here are some quick links to these."))
		}
	}
}
